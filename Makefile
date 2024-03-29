VERSIONS    ?=  9.5 10 11 12 13
LATEST	    ?= 11
REPO	    ?= unera
SKIP_LAST   ?= no

build:
	@set -e; \
	for v in $(VERSIONS); do \
	    cp Dockerfile.in Dockerfile; \
	    VERSION=$$v \
		perl -pi -e 's/\$$\{([^}]+)\}/defined $$ENV{$$1} ? $$ENV{$$1} : $$&/eg' Dockerfile; \
	    TAGS="-t $(REPO)/pgpair:$$v"; \
	    if test $$v = $(LATEST); then \
	    	TAGS="$$TAGS -t $(REPO)/pgpair:latest"; \
	    fi; \
	    echo docker build . $$TAGS; \
	    docker build . $$TAGS; \
	done;

upload:
	@set -e; \
	for v in $(VERSIONS); do \
	    docker push $(REPO)/pgpair:$$v; \
	done; \
	if test $(SKIP_LAST) = no; then \
	    docker push $(REPO)/pgpair:latest; \
	else \
	    echo skip :last uploading; \
	fi
        
