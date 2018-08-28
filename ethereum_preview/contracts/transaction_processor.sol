pragma solidity ^0.4.24;
/*
 * Implements the transaction processor for Ethereum.
 * Contains a contract for contract registry and a
 * contract for enclave registry.
 */


contract ContractRegistry {

    //Defines info for each provisioning service stored in a contract's enclave
    struct PSInfo {
        bytes32 ps_public_key;
        string encrypted_contract_state;
        int index;
    }

    //Defines info for each enclave stored in a contract's enclave list
    struct ContractEnclaveInfo {
        bytes32 verifying_key; //sometimes refered to as enclave_id
        string contract_state_encryption_key;
        string enclave_signature;
        bytes32[] ps_list_keys;
        mapping(bytes32 => PSInfo) ps_list;
        bool initialized; // once true, enclave info is immutable
    }

    //Define info to be stored for each contract
    struct ContractInfo {
        bytes32 contract_id;
        string code_hash;
        bytes32[] ps_public_keys_list;
        bytes32[] enclave_list_keys;
        mapping(bytes32 => ContractEnclaveInfo) enclave_list;
        address creator;
    }

    // contracts contains all registered contracts
    mapping(bytes32 => ContractInfo) public contracts;

    //keySet stores all registered contracts' ID's
    bytes32[] public keySet;

    event contractRegistered(bytes32 contract_id);

    // Registers a new contract
    function register(bytes32 contract_id, string code_hash,
        bytes32[] ps_public_keys_list) public {
        ContractInfo storage contract_info =  contracts[contract_id];

        //check if contract_id already exists
        require(contract_info.contract_id == 0, 'Contract already exists');
        require(contract_id != 0, 'Invalid contract ID argument');
        require(bytes(code_hash).length != 0, 'Invalid code hash argument');
        require(ps_public_keys_list.length > 0, 'Provisioning service keys must be nonempty');

        //set values of ContractInfo
        contract_info.contract_id = contract_id;
        contract_info.code_hash = code_hash;
        contract_info.ps_public_keys_list = ps_public_keys_list;
        contract_info.creator = msg.sender;

        //update contract registry
        contracts[contract_id] = contract_info;

        //add contract_id to keySet
        keySet.push(contract_id);

        emit contractRegistered(contract_id);
    }


    // Initiates addition of an enclave to a contract's enclave list
    function addEnclaveInit(bytes32 contract_id, bytes32 verifying_key,
        string contract_state_encryption_key, string enclave_signature,
        address enclave_contract_addr)
        public {

        ContractInfo storage contract_info = contracts[contract_id];
        //make sure contract is registered
        require(contract_info.contract_id != 0, 'Contract not found');

        //make sure enclave is being added by the contract creator
        if(msg.sender != contract_info.creator) { revert(); }

        mapping(bytes32 => ContractEnclaveInfo) enclave_list = contract_info.enclave_list;
        ContractEnclaveInfo storage contract_enclave_info = enclave_list[verifying_key];

        EnclaveRegistry enclave_registry = EnclaveRegistry(enclave_contract_addr);
        bytes32 enclave_registry_verifying_key;
        string memory enclave_registry_encryption_key;
        string memory enclave_registry_owner_id;
        string memory enclave_registry_lrbc;
        (enclave_registry_verifying_key, enclave_registry_encryption_key,
        enclave_registry_owner_id, enclave_registry_lrbc) = enclave_registry.getEnclave(verifying_key);
        require(enclave_registry_verifying_key != 0, 'Enclave not registered');

        //check if enclave is already in enclave_list
        require(contract_enclave_info.verifying_key == 0, 'Enclave already in list');

        //set values of EnclaveInfo
        contract_enclave_info.verifying_key = verifying_key;
        contract_enclave_info.contract_state_encryption_key = contract_state_encryption_key;
        contract_enclave_info.enclave_signature = enclave_signature;
        contract_enclave_info.initialized = false;

        //update enclave_list
        contract_info.enclave_list[verifying_key] = contract_enclave_info;
    }

    // Returns contract associated with given ID
    function getContract(bytes32 id)
        public view returns(bytes32 contract_id, string code_hash,
        bytes32[] ps_public_keys_list, bytes32[] enclave_list_keys) {

        ContractInfo storage contract_info = contracts[id];

        //make sure contract is registered
        require(contract_info.contract_id != 0, 'Contract not found');

        contract_id = contract_info.contract_id;
        code_hash = contract_info.code_hash;
        ps_public_keys_list = contract_info.ps_public_keys_list;
        enclave_list_keys = contract_info.enclave_list_keys;
    }

    // Returns ID's of all enclaves in a contract's enclave list
    function getEnclaveIDs(bytes32 id)
        public view returns(bytes32[] enclaves) {

        ContractInfo storage contract_info = contracts[id];

        //make sure contract is registered
        require(contract_info.contract_id != 0, 'Contract not found');

        enclaves = contract_info.enclave_list_keys;
    }

    // Returns enclave info of a specified enclave in a specified contract's
    // enclave list. Note that enclave_id is the enclave's verifying_key.
    // Enclave must be registered in the enclave registry.
    function getEnclave(bytes32 contract_id, bytes32 enclave_id)
        public view returns(bytes32 verifying_key, string contract_state_encryption_key,
        bytes32[] ps_list_keys) {

        ContractInfo storage contract_info = contracts[contract_id];
        //make sure contract is registered
        require(contract_info.contract_id != 0, 'Contract not found');

        ContractEnclaveInfo storage enclave_info = contract_info.enclave_list[enclave_id];
        require(enclave_info.verifying_key != 0, 'Enclave not found');

        verifying_key = enclave_info.verifying_key;
        contract_state_encryption_key = enclave_info.contract_state_encryption_key;
        ps_list_keys = enclave_info.ps_list_keys;
    }

    // Adds a provisioning service to a specified enclave in a specified
    // contract's enclave list. Provisioning service must be in the contract's
    // list of provisioning services
    function addProvisioningServiceToEnclave(bytes32 contract_id, bytes32 enclave_id,
        bytes32 ps_public_key, string encrypted_contract_state, int index)
        public {

        ContractInfo storage contract_info = contracts[contract_id];
        require(contract_info.contract_id != 0, 'Contract not found');
        //make sure ps is being added by the contract creator
        require(msg.sender == contract_info.creator, 'Sender not authorized to add provisioning service');

        ContractEnclaveInfo storage enclave_info = contract_info.enclave_list[enclave_id];
        require(enclave_info.verifying_key != 0, 'Enclave not found');
        require(!enclave_info.initialized, 'Enclave already initialized. Cannot add provisioning services.');

        PSInfo storage ps_info = enclave_info.ps_list[ps_public_key];
        require(ps_info.ps_public_key == 0, 'Provisioning service already registered');

        //check that this provisioning service is in contract's list of pservices
        bool ps_permission = false;
        bytes32[] storage ps_list = contract_info.ps_public_keys_list;
        for (uint i = 0; i < ps_list.length; i++)
        {
            if (ps_list[i] == ps_public_key)
            {
                ps_permission = true;
                break;
            }
        }
        require(ps_permission == true, 'Provisioning service is unavailable for this contract');
        //create provisioning service info object from arguments
        ps_info.ps_public_key = ps_public_key;
        ps_info.encrypted_contract_state = encrypted_contract_state;
        ps_info.index = index;

        //update enclave info
        enclave_info.ps_list[ps_public_key] = ps_info;
        enclave_info.ps_list_keys.push(ps_public_key);

        //update contract info
        contract_info.enclave_list[enclave_id] = enclave_info;

        //update contract registry
        contracts[contract_id] = contract_info;

    }

    // Completes the addition of an enclave to a contract's enclave list.
    // Ensures no future changes to this enclave's info.
    function addEnclaveCompletion(bytes32 contract_id, bytes32 enclave_id)
        public {

        ContractInfo storage contract_info = contracts[contract_id];
        require(contract_info.contract_id != 0, 'Contract not found');
        //make sure enclave is being added by the contract creator
        require(msg.sender == contract_info.creator, 'Sender not authorized to add enclave to contract');

        ContractEnclaveInfo storage enclave_info = contract_info.enclave_list[enclave_id];
        require(enclave_info.verifying_key != 0, 'Enclave not found');
        require(!enclave_info.initialized, 'Enclave initialization already complete');

        //checks - some seem redundant, could be shortened/fine-tuned
        require(bytes(enclave_info.contract_state_encryption_key).length != 0, 'Contract state encryption key not initialized');
        require(bytes(enclave_info.enclave_signature).length != 0, 'Enclave signature not initialized');
        require(enclave_info.ps_list_keys.length > 0, 'Provisioning service list not initialized');

        //ensure all ps are initilized
        for (uint i = 0; i < enclave_info.ps_list_keys.length; i++)
        {
            bytes32 key = enclave_info.ps_list_keys[i];
            PSInfo storage ps_info = enclave_info.ps_list[key];
            require(ps_info.ps_public_key != 0);
            require(bytes(ps_info.encrypted_contract_state).length != 0);
        }

        //set initialized to true
        contracts[contract_id].enclave_list[enclave_id].initialized = true;

        //add enclave verifying_key to enclave_list_keys
        bytes32[] storage enclave_list_keys = contract_info.enclave_list_keys;
        enclave_list_keys.push(enclave_id);

    }

    // Returns specified provisioning service of a specified enclave of a
    // specified contract's enclave list
    function getProvisioningService(bytes32 contract_id, bytes32 enclave_id,
        bytes32 ps_id)
        public view returns (bytes32 ps_public_key, string encrypted_contract_state,
        int index) {

        ContractInfo storage contract_info = contracts[contract_id];
        require(contract_info.contract_id != 0, 'Contract not found');

        ContractEnclaveInfo storage enclave_info = contract_info.enclave_list[enclave_id];
        require(enclave_info.verifying_key != 0, 'Enclave not found');
        require(enclave_info.initialized, 'Enclave initialization incomplete');

        PSInfo storage ps_info = enclave_info.ps_list[ps_id];
        require(ps_info.ps_public_key != 0, 'Provisioning service not found');

        ps_public_key = ps_info.ps_public_key;
        encrypted_contract_state = ps_info.encrypted_contract_state;
        index = ps_info.index;
    }

    // Deletes an enclave from a contract's enclave list
    function deleteContractEnclave(bytes32 contract_id, bytes32 enclave_id)
        public {

        ContractInfo storage contract_info = contracts[contract_id];
        require(contract_info.contract_id != 0, 'Contract not found');
        //make sure enclave is being deleted by the contract creator
        require(msg.sender == contract_info.creator, 'Sender not authorized to delete enclave');

        ContractEnclaveInfo storage enclave_info = contract_info.enclave_list[enclave_id];
        require(enclave_info.verifying_key != 0, 'Enclave not found');


        for(uint i = 0; i < contracts[contract_id].enclave_list[enclave_id].ps_list_keys.length; i++)
        {
            bytes32 ps_key = contracts[contract_id].enclave_list[enclave_id].ps_list_keys[i];
            delete(contracts[contract_id].enclave_list[enclave_id].ps_list[ps_key]);
        }

        //remove this key from the keys of the enclave list
        contracts[contract_id].enclave_list_keys = removeFromArray(contract_info.enclave_list_keys, enclave_id);

        //delete enclave
        delete(contracts[contract_id].enclave_list[enclave_id]);
    }

    // Private helper function to keep arrays updated when values are deleted
    function removeFromArray(bytes32[] storage array, bytes32 key)
        private returns(bytes32[]) {

        bool found = false;
        for (uint i  = 0; i < array.length; i++)
        {
            if (array[i] == key)
            {
                found = true;
                break;
            }
        }
        if (found == false) return;

        for (i; i < array.length - 1; i++)
        {
            array[i] = array[i+1];
        }
        array.length--;
        return array;
    }

    //Deletes specified contract, calls to delete all enclaves in enclaves list
    function deleteContract(bytes32 contract_id)
        public {

        ContractInfo storage contract_info = contracts[contract_id];
        require(contract_info.contract_id != 0, 'Contract not found');
        //make sure contract is being deleted by the contract creator
        require(msg.sender == contract_info.creator, 'Sender not authorized to delete contract');

        //delete components of each enclave -- might be unnecessary
        for (uint i = 0; i < contracts[contract_id].enclave_list_keys.length; i++)
        {
            deleteContractEnclave(contract_id, contracts[contract_id].enclave_list_keys[i]);
        }

        //delete contract
        delete(contracts[contract_id]);

        //remove contract key from keySet
        keySet = removeFromArray(keySet, contract_id);
    }

    // Returns ID's of all registered contracts
    function getContractIDs()
        view public returns (bytes32[])
    {
        return keySet;
    }


}

contract EnclaveRegistry {
    // Define info to be stored for each enclave
    struct EnclaveInfo {
         bytes32 verifying_key;
         string encryption_key;
         string owner_id;
         string last_registration_block_context;
    }
    address public lastMessageSender;
    address public result;


    // This declares a state variable that
    // stores an `EnclaveInfo` struct for each enclave verifying key.
    mapping(bytes32 => EnclaveInfo) public enclaves;

    // Stores the ID's (veriyfing_key) of all registered enclaves
    bytes32[] public keySet;

    // Registers a new enclave
    function register(bytes32 verifying_key, string encryption_key,
      string owner_id, string last_registration_block_context) public
    {

        // assigns reference
        EnclaveInfo storage info = enclaves[verifying_key];

        //check if enclave is already registered
        require (info.verifying_key == 0, "Enclave is already registered.");


        //set values of EnclaveInfo object
        info.verifying_key = verifying_key;
        info.encryption_key = encryption_key;
        info.owner_id = owner_id;
        info.last_registration_block_context = last_registration_block_context;


        //update enclave registry
        enclaves[verifying_key] = info;

        //updates keySet
        keySet.push(verifying_key);
    }

    // Returns enclave info by its ID (verifying_key)
    function getEnclave(bytes32 enclave_id)
      view public returns (bytes32 verifying_key, string encryption_key,
      string owner_id, string last_registration_block_context)
    {
        EnclaveInfo storage info = enclaves[enclave_id];
        verifying_key = info.verifying_key;
        //ensure enclave corresponding to id has been initialized
        require (verifying_key != 0, "Enclave not found");
        encryption_key = info.encryption_key;
        owner_id = info.owner_id;
        last_registration_block_context = info.last_registration_block_context;
    }

    // Returns ID's of all registered enclaves
    function getEnclaveIDs()
        view public returns (bytes32[])
    {
        return keySet;
    }

    // Deletes specified enclave
    function deleteEnclaveByID(bytes32 enclave_id) public {
        EnclaveInfo storage info = enclaves[enclave_id];
        //ensure enclave corresponding to id exists
        require (info.verifying_key.length != 0, "No enclave with ID");
        delete enclaves[enclave_id];
        removeFromArray(keySet, enclave_id);

    }

    // Private helper function to keep arrays updated when values are deleted
    function removeFromArray(bytes32[] storage array, bytes32 key)
        private returns(bytes32[]) {

        bool found = false;
        for (uint i  = 0; i < array.length; i++)
        {
            if (array[i] == key)
            {
                found = true;
                break;
            }
        }
        if (found == false) return;

        for (i; i < array.length - 1; i++)
        {
            array[i] = array[i+1];
        }
        array.length--;
        return array;
    }

    // Verify a signature -- still under development (not working)
    function verify(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        public constant returns(bool) {

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, hash));
        return ecrecover(prefixedHash, v, r, s) == msg.sender;
    }
}
