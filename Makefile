ifndef BUILD_CMAKE_ARGS
	BUILD_CMAKE_ARGS:=
endif

all: release

debug:
	mkdir -p bin-dbg
	cd bin-dbg && cmake $(BUILD_CMAKE_ARGS) -DCMAKE_BUILD_TYPE=Debug ../ && make

release:
	mkdir -p bin-opt
	cd bin-opt && cmake $(BUILD_CMAKE_ARGS) -DCMAKE_BUILD_TYPE=Release ../ && make

clean:
	rm -rf bin-opt
	rm -rf bin-dbg

test: debug
	cd bin-dbg && ctest

test-release: release
	cd bin-opt && ctest

install: debug
	cd bin-dbg && make install

install-release: release
	cd bin-opt && make install

uninstall: debug
	cd bin-dbg && make uninstall

uninstall-release: release
	cd bin-opt && make uninstall
