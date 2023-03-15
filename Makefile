synfini-examples-package-v1.dar: v1/daml.yaml $(shell find v1 -name '*.daml')
	echo "Building v1 dar" && cd v1 && daml build -o ../synfini-examples-package-v1.dar

synfini-examples-package-v2.dar: v2/daml.yaml $(shell find v2 -name '*.daml')
	echo "Building v2 dar" && cd v2 && daml build -o ../synfini-examples-package-v2.dar

synfini-examples-package-upgrade.dar: synfini-examples-package-v1.dar synfini-examples-package-v2.dar upgrade/daml.yaml $(shell find upgrade -name '*.daml')
	echo "Building upgrade dar" && cd upgrade && daml build -o ../synfini-examples-package-upgrade.dar

synfini-examples-package-upgrade-scripts.dar: synfini-examples-package-upgrade.dar scripts/daml.yaml $(shell find scripts -name '*.daml')
	echo "Building scripts dar" && cd scripts && daml build -o ../synfini-examples-package-upgrade-scripts.dar
