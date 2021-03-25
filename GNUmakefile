# Convenience wrapper for CMake commands

ifeq ($(OS),Windows_NT)
	$(error On Windows, use "cmd //c make.bat" instead of "make")
endif

ifndef BUILD_CMAKE_ARGS
	BUILD_CMAKE_ARGS:=
endif

ifndef BUILD_DIR
	BUILD_DIR:=./build
endif

ifndef PYTHON
	PYTHON:=python3
endif

all: release

release:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake $(BUILD_CMAKE_ARGS) -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./bin .. && cmake --build . --target install

debug:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake $(BUILD_CMAKE_ARGS) -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=./bin .. && cmake --build . --target install

clean:
	rm -rf $(BUILD_DIR)

test:
	cd $(BUILD_DIR) && ctest

update:
	$(PYTHON) src/cmake/make_update.py

format:
	$(PYTHON) src/cmake/make_format.py
