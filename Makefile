JUNIT_URL := https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.0/junit-platform-console-standalone-1.10.0.jar
JUNIT_JAR := libs/junit.jar

PMD_VERSION := 7.27.0
PMD_URL := https://github.com/pmd/pmd/releases/download/pmd_releases/$(PMD_VERSION)/pmd-dist-$(PMD_VERSION)-bin.zip
PMD_BIN := libs/pmd-bin-$(PMD_VERSION)/bin/pmd

SPOTBUGS_VERSION := 4.10.4
SPOTBUGS_URL := https://github.com/spotbugs/spotbugs/releases/download/$(SPOTBUGS_VERSION)/spotbugs-$(SPOTBUGS_VERSION).tgz
SPOTBUGS_BIN := libs/spotbugs-$(SPOTBUGS_VERSION)/bin/spotbugs

SRCS := $(shell find src -name '*.java' 2>/dev/null)
TESTS := $(shell find test -name '*.java' 2>/dev/null)

.PHONY: deps build test clean pmd spotbugs

deps: $(JUNIT_JAR)

$(JUNIT_JAR):
	@mkdir -p libs
	@curl -sSL -o $@ $(JUNIT_URL)

build: deps
	@mkdir -p build
	javac --release 17 -d build -cp $(JUNIT_JAR) $(SRCS) $(TESTS)

test: build
	java -jar $(JUNIT_JAR) --class-path build --scan-class-path

$(PMD_BIN):
	@mkdir -p libs
	@curl -sSL -o libs/pmd-dist.zip $(PMD_URL)
	@unzip -q -o libs/pmd-dist.zip -d libs/
	@rm -f libs/pmd-dist.zip

pmd: $(PMD_BIN)
	@$(PMD_BIN) check -d src -R category/java/design.xml/CyclomaticComplexity -f text; true

$(SPOTBUGS_BIN):
	@mkdir -p libs
	@curl -sSL -o libs/spotbugs.tgz $(SPOTBUGS_URL)
	@tar -xzf libs/spotbugs.tgz -C libs/
	@rm -f libs/spotbugs.tgz

spotbugs: $(SPOTBUGS_BIN) build
	@$(SPOTBUGS_BIN) -textui -effort:max build; true

clean:
	rm -rf build libs
