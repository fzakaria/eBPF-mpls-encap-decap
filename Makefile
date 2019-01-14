
######################################################################################################
# The output target generated by this makefile
BPF_TARGET := mpls.bpf
# Use wildcard expansion to find all source files
BPF_SRC_FILES := $(wildcard *_kern.c)
BPF_OBJ_FILES := $(BPF_SRC_FILES:.c=.o)
BPF_DEP_FILES := $(BPF_OBJ_FILES:%.o=%.d)
######################################################################################################
USER_TARGET := mpls.bin
# Use wildcard expansion to find all source files
USER_SRC_FILES := $(wildcard *_user.c)
USER_OBJ_FILES := $(USER_SRC_FILES:.c=.o)
USER_DEP_FILES := $(USER_OBJ_FILES:%.o=%.d)
######################################################################################################
SRC_FILES := $(wildcard *.c)
OBJ_FILES := $(wildcard *.o)
DEP_FILES := $(wildcard *.d)
######################################################################################################
# clang is the front-end compiler for various languages and uses LLVM as it's backend
CLANG ?= clang
CLANG_FORMAT ?=clang-format
LLC ?= llc
######################################################################################################


#A phony target is one that is not really the name of a file;
#rather it is just a name for a recipe to be executed when you make an explicit request.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
.PHONY: clean all format docker

# Make the default goal explicit rather than the first target found
# https://www.gnu.org/software/make/manual/html_node/Special-Variables.html#Special-Variables
.DEFAULT_GOAL := all

docker:
	@docker build -t mpls-ebpf-build:latest -f Dockerfile.build .
	@docker run -v $(shell pwd):/eBPF-mpls-encap-decap mpls-ebpf-build:latest

all : format $(BPF_TARGET) $(USER_TARGET)
	@echo "Finished."

format:
	@echo "Formating $(SRC_FILES) according to Google's style"
	@# $< the first prerequisite (usually the source file)
	@# -i : modify the file inline
	@# -style : set the style to the desired type
	$(CLANG_FORMAT) -i -style Google -sort-includes $(SRC_FILES)

$(USER_TARGET) : $(USER_OBJ_FILES)
	$(CLANG) -o $(USER_TARGET) $(USER_OBJ_FILES)
	@chmod +x $(USER_TARGET)

$(USER_OBJ_FILES) : $(USER_SRC_FILES)
	@# $@ is the name of the file being generated
	@# $< the first prerequisite (usually the source file)
	@echo "Building the MPLS user file..."
	@echo "Building $@ from $<"
	@# -c : Only run preprocess, compilation & assemble steps
	@# -g : Generate source-level debug information
	@# -Weverything : Enable all warning (seriously)
	@# -o : Write output to file <arg>
	@# -x : Treat subsequent input files as having type <language>
	@# -target : Target the bpf instruction set
	@# -O2 : Moderate level of optimization which enables most optimizations.
	@# -MMD :  Write a depfile containing user headers
	@# -Wno-pedantic : eBPF has you explicitly cast which is pedantic. Turn off the warning.
	$(CLANG) -MMD -O2 -Weverything -Wno-pedantic -c -g -o $@ -x c $<

$(BPF_TARGET): $(BPF_OBJ_FILES)
	@# $@ is the name of the file being generated
	@# $< the first prerequisite (usually the source file)
	@echo "Linking $< to build $@"
	@# -march : Architecture of generated code
	${LLC} -march=bpf -filetype=obj $< -o $@

$(BPF_OBJ_FILES) : $(BPF_SRC_FILES)
	@# $@ is the name of the file being generated
	@# $< the first prerequisite (usually the source file)
	@echo "Building the MPLS BPF..."
	@echo "Building $@ from $<"
	@# -S : Only run preprocess and compilation steps
	@# -emit-llvm : Use the LLVM representation for assembler and object files
	@# -g : Generate source-level debug information
	@# -Weverything : Enable all warning (seriously)
	@# -o : Write output to file <arg>
	@# -x : Treat subsequent input files as having type <language>
	@# -target : Target the bpf instruction set
	@# -O2 : Moderate level of optimization which enables most optimizations.
	@# -MMD :  Write a depfile containing user headers
	@# -Wno-pedantic : eBPF has you explicitly cast which is pedantic. Turn off the warning.
	$(CLANG) -D__KERNEL__ -MMD -O2 -target bpf -Weverything -Wno-pedantic -S -emit-llvm -g -o $@ -x c $<

clean:
	@echo "Cleaning the build..."
	rm -f $(DEP_FILES) $(OBJ_FILES) $(TARGET) $(USER_TARGET)


# MMD generates dependency files in Makefile format
# therefore we have to include the rules.
-include $(BPF_DEP_FILES) $(USER_DEP_FILES)

