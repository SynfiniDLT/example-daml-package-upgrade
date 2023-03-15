.PHONY: build test clean

.build/synfini-examples-package-v1.dar: v1/daml.yaml $(shell find v1 -name '*.daml')
	cd v1 && daml build -o ../.build/synfini-examples-package-v1.dar

.build/synfini-examples-package-v2.dar: v2/daml.yaml $(shell find v2 -name '*.daml')
	cd v2 && daml build -o ../.build/synfini-examples-package-v2.dar

.build/synfini-examples-package-upgrade.dar: .build/synfini-examples-package-v1.dar .build/synfini-examples-package-v2.dar upgrade/daml.yaml $(shell find upgrade -name '*.daml')
	cd upgrade && daml build -o ../.build/synfini-examples-package-upgrade.dar

.build/synfini-examples-package-upgrade-scripts.dar: .build/synfini-examples-package-upgrade.dar scripts/daml.yaml $(shell find scripts -name '*.daml')
	cd scripts && daml build -o ../.build/synfini-examples-package-upgrade-scripts.dar

build: .build/synfini-examples-package-v1.dar .build/synfini-examples-package-v2.dar .build/synfini-examples-package-upgrade.dar .build/synfini-examples-package-upgrade-scripts.dar

test: .build/synfini-examples-package-upgrade-scripts.dar test/daml.yaml $(shell find test -name '*.daml')
	cd test && daml test

clean:
	cd v1 && daml clean
	cd v2 && daml clean
	cd upgrade && daml clean
	cd scripts && daml clean
	cd test && daml clean
	daml clean
	rm -rf .build
