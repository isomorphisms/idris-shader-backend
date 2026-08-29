IDRIS2 ?= idris2
IDRIS2_GLSLES ?= ./build/exec/idris2-glsles
IDRIS2_MALI_MOCK ?= ./build/exec/idris2-mali-mock

.PHONY: build backend mali-mock generate generate-compiler test backend-test mali-mock-test check clean

build:
	$(IDRIS2) --build idris-glsl-es.ipkg

backend:
	$(IDRIS2) --build backend.ipkg

mali-mock:
	$(IDRIS2) --build mali-mock.ipkg

generate:
	$(IDRIS2) --build generate.ipkg
	./build/exec/idris-glsl-es-generate

generate-compiler: backend
	$(IDRIS2_GLSLES) --cg glsles \
		--directive dump-ir=generated/compiler-sphere.ir \
		--source-dir src --output-dir generated \
		src/Example/CompilerSphere.idr -o compiler-sphere
	$(IDRIS2_GLSLES) --cg glsles \
		--directive dump-ir=generated/disc-reveal.ir \
		--source-dir src --output-dir generated \
		src/Example/DiscReveal.idr -o disc-reveal

test:
	$(IDRIS2) --build tests.ipkg
	./build/exec/idris-glsl-es-tests

backend-test: backend
	python3 tools/check_backend.py
	python3 tools/check_shared_factor_portrait.py
	python3 tools/check_analytic_continuation.py
	python3 tools/check_surfer_root_search.py

mali-mock-test: mali-mock
	$(IDRIS2_MALI_MOCK) --cg mali-mock \
		--source-dir src --output-dir /tmp \
		src/Example/MaliMockSmoke.idr -o mali-mock-smoke
	python3 tools/check_mali_mock.py /tmp/mali-mock-smoke.mali.mock

check: generate test backend-test mali-mock-test
	python3 tools/check_glsl.py generated/fullscreen.vert generated/sphere.frag \
		generated/compiler-sphere.frag generated/disc-reveal.frag

clean:
	$(IDRIS2) --clean idris-glsl-es.ipkg
	$(IDRIS2) --clean generate.ipkg
	$(IDRIS2) --clean tests.ipkg
	$(IDRIS2) --clean backend.ipkg
	$(IDRIS2) --clean mali-mock.ipkg
