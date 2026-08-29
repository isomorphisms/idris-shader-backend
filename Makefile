IDRIS2 ?= idris2
IDRIS2_GLSLES ?= ./build/exec/idris2-glsles
CC ?= cc
EGL_LIBS ?= -lEGL
GLES_LIBS ?= -lGLESv3
POWERVR_OUTPUT_DIR ?= generated

.PHONY: build backend generate generate-compiler test backend-test check clean \
	powervr-primitives powervr-primitives-frag powervr-primitives-host \
	powervr-phone-accept

build:
	$(IDRIS2) --build idris-glsl-es.ipkg

backend:
	$(IDRIS2) --build backend.ipkg

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

powervr-primitives-frag: backend
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/SetPixel3RGB5239182.idr -o set-pixel-3-rgb-52-39-182
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/SetBlock32x32RGB5239182.idr -o set-block-32x32-rgb-52-39-182
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/DotVector4Covector4.idr -o dot-vector4-covector4
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/DotVector32Covector32.idr -o dot-vector32-covector32
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/SubtractVector8Norm.idr -o subtract-vector8-norm
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/RotateDifference8ToE1.idr -o rotate-difference8-to-e1
	$(IDRIS2_GLSLES) --cg glsles --source-dir src --output-dir $(POWERVR_OUTPUT_DIR) \
		src/Example/GivensRotate2ToE1.idr -o givens-rotate2-to-e1

powervr-primitives-host:
	mkdir -p build
	$(CC) -std=c11 -O2 -Wall -Wextra tools/powervr_primitives.c \
		-o build/powervr-primitives $(EGL_LIBS) $(GLES_LIBS) -lm

powervr-primitives: powervr-primitives-frag powervr-primitives-host

powervr-phone-accept:
	sh tools/accept_powervr_phone.sh

test:
	$(IDRIS2) --build tests.ipkg
	./build/exec/idris-glsl-es-tests

backend-test: backend
	python3 tools/check_backend.py
	python3 tools/check_shared_factor_portrait.py
	python3 tools/check_analytic_continuation.py
	python3 tools/check_surfer_root_search.py
	python3 tools/check_powervr_primitives.py
	sh -n tools/accept_powervr_phone.sh

check: generate test backend-test
	python3 tools/check_glsl.py generated/fullscreen.vert generated/sphere.frag \
		generated/compiler-sphere.frag generated/disc-reveal.frag

clean:
	$(IDRIS2) --clean idris-glsl-es.ipkg
	$(IDRIS2) --clean generate.ipkg
	$(IDRIS2) --clean tests.ipkg
	$(IDRIS2) --clean backend.ipkg
