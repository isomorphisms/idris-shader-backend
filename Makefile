IDRIS2 ?= idris2
IDRIS2_GLSLES ?= ./build/exec/idris2-glsles
IDRIS2_MALI_MOCK ?= ./build/exec/idris2-mali-mock
IDRIS2_FRAGMENT_MOCKS ?= ./build/exec/idris2-fragment-mocks

FRAGMENT_MOCK_TARGETS = \
	powervr-ge8322-mock \
	mali-g57-valhall-mock \
	switch-maxwell-sm53-mock \
	steam-rdna2-vulkan-mock \
	webgpu-wgsl-mock \
	apple-metal-mock \
	nvidia-hopper-sm90-mock \
	nvidia-blackwell-sm100-mock \
	adreno-tile-mock

.PHONY: build backend mali-mock fragment-mocks generate generate-compiler test backend-test mali-mock-test fragment-mock-test check clean

build:
	$(IDRIS2) --build idris-glsl-es.ipkg

backend:
	$(IDRIS2) --build backend.ipkg

mali-mock:
	$(IDRIS2) --build mali-mock.ipkg

fragment-mocks:
	$(IDRIS2) --build fragment-mocks.ipkg

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

fragment-mock-test: fragment-mocks
	rm -rf /tmp/idris-fragment-mocks
	mkdir -p /tmp/idris-fragment-mocks
	@for target in $(FRAGMENT_MOCK_TARGETS); do \
		echo "Wegert mock -> $$target"; \
		$(IDRIS2_FRAGMENT_MOCKS) --cg $$target \
			--source-dir src --output-dir /tmp/idris-fragment-mocks \
			src/Example/WegertFragmentMocks.idr -o wegert || exit $$?; \
		echo "Givens mock -> $$target"; \
		$(IDRIS2_FRAGMENT_MOCKS) --cg $$target \
			--source-dir src --output-dir /tmp/idris-fragment-mocks \
			src/Example/GivensFragmentMocks.idr -o givens || exit $$?; \
	done
	python3 tools/check_fragment_mocks.py /tmp/idris-fragment-mocks

check: generate test backend-test mali-mock-test fragment-mock-test
	python3 tools/check_glsl.py generated/fullscreen.vert generated/sphere.frag \
		generated/compiler-sphere.frag generated/disc-reveal.frag

clean:
	$(IDRIS2) --clean idris-glsl-es.ipkg
	$(IDRIS2) --clean generate.ipkg
	$(IDRIS2) --clean tests.ipkg
	$(IDRIS2) --clean backend.ipkg
	$(IDRIS2) --clean mali-mock.ipkg
	$(IDRIS2) --clean fragment-mocks.ipkg
