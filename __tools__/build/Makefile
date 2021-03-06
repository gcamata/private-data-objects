# Copyright 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SRCDIR defaults to the current directory
# DSTDIR defaults to _dev under the current directory
# Both can be overridden with environment variables
SRCDIR?=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DSTDIR?=$(abspath $(SRCDIR)/_dev)

KEYGEN=$(abspath $(SRCDIR)/../make-keys)
CNFGEN=$(abspath $(SRCDIR)/../make-config)
PKGGEN=$(abspath $(SRCDIR)/../rebuild.sh)

PY_VERSION=${shell python3 --version | sed 's/Python \(3\.[0-9]\).*/\1/'}
PYTHON_DIR=$(DSTDIR)/lib/python$(PY_VERSION)/site-packages/

all: environment template packages keys conf

clean :
	rm -rf $(DSTDIR)

environment : $(PYTHON_DIR)

$(PYTHON_DIR) : $(DSTDIR)
	virtualenv -p python3 --no-download $(DSTDIR)
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade pip
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade setuptools
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade toml
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade requests
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade colorlog
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade twisted
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade pyyaml
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade google
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade protobuf
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade secp256k1
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade cryptography
	. $(abspath $(DSTDIR)/bin/activate) ; pip install --upgrade pyparsing

$(DSTDIR) :
	mkdir -p $(DSTDIR)

packages :
	. $(abspath $(DSTDIR)/bin/activate) ; $(PKGGEN)

keys :
	. $(abspath $(DSTDIR)/bin/activate) ; \
		for i in 1 2 3 4 5 ; do $(KEYGEN) --keyfile $(DSTDIR)/opt/pdo/keys/eservice$${i} --format skf; done
	. $(abspath $(DSTDIR)/bin/activate) ; \
		for i in 1 2 3 4 5 ; do $(KEYGEN) --keyfile $(DSTDIR)/opt/pdo/keys/pservice$${i} --format pem; done
	. $(abspath $(DSTDIR)/bin/activate) ; \
		for i in 1 2 3 4 5 6 7 8 9 10 ; do $(KEYGEN) --keyfile $(DSTDIR)/opt/pdo/keys/user$${i} --format pem; done

conf :
	. $(abspath $(DSTDIR)/bin/activate) ; \
		$(CNFGEN) --template eservice.toml --template-directory $(SRCDIR)/opt/pdo/etc/template \
		--node-base eservice --http-base 7100 --output $(DSTDIR)/opt/pdo/etc --count 5
	. $(abspath $(DSTDIR)/bin/activate) ; \
		$(CNFGEN) --template pservice.toml --template-directory $(SRCDIR)/opt/pdo/etc/template \
		--node-base pservice --http-base 7000 --output $(DSTDIR)/opt/pdo/etc --count 5
	cp $(SRCDIR)/opt/pdo/etc/template/pcontract.toml $(DSTDIR)/opt/pdo/etc

template :
	mkdir -p $(DSTDIR)/opt/pdo/data
	mkdir -p $(DSTDIR)/opt/pdo/etc
	mkdir -p $(DSTDIR)/opt/pdo/keys
	mkdir -p $(DSTDIR)/opt/pdo/logs

.PHONY : conf environment keys packages template
