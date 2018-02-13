#!/usr/bin/env python3
#
# Copyright 2014 Blender Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# This script generates either header or implementation file from
# a CUDA header files.
#
# Usage: cuew hdr|impl [/path/to/cuda/includes]
#  - hdr means header file will be generated and printed to stdout.
#  - impl means implementation file will be generated and printed to stdout.
#  - /path/to/cuda/includes is a path to a folder with cuda.h and cudaGL.h
#    for which wrangler will be generated.

import os
import sys
from cuda_errors import CUDA_ERRORS
from pycparser import c_parser, c_ast, parse_file
from subprocess import Popen, PIPE

INCLUDE_DIR = "/usr/include"
FILES = ["cuda.h", "cudaGL.h", 'nvrtc.h']

TYPEDEFS = []
FUNC_TYPEDEFS = []
SYMBOLS = []
DEFINES = []
DEFINES_V2 = []
ERRORS = []


class FuncDefVisitor(c_ast.NodeVisitor):
    indent = 0
    prev_complex = False
    dummy_typedefs = ['size_t', 'CUdeviceptr', 'uint32_t', 'uint64_t',
                      'cuuint32_t', 'cuuint64_t'];

    def _get_quals_string(self, node):
        if node.quals:
            return ' '.join(node.quals) + ' '
        return ''

    def _get_ident_type(self, node):
        if isinstance(node, c_ast.PtrDecl):
            result = self._get_ident_type(node.type)
            if not isinstance(node.type, c_ast.FuncDecl):
                result += "*"
            return result
        if isinstance(node, c_ast.ArrayDecl):
            return self._get_ident_type(node.type)
        elif isinstance(node, c_ast.Struct):
            if node.name:
                return 'struct ' + node.name
            else:
                self.indent += 1
                struct = self._stringify_struct(node)
                self.indent -= 1
                return "struct {\n" + \
                       struct + ("  " * self.indent) + "}"
        elif isinstance(node, c_ast.Union):
            self.indent += 1
            union = self._stringify_struct(node)
            self.indent -= 1
            result = "union "
            if node.name:
                result += node.name + " "
            result += "{\n" + union + ("  " * self.indent) + "}"
            return result
        elif isinstance(node, c_ast.Enum):
            if node.name is not None:
                return 'enum ' + node.name
            else:
                return 'enum '
        elif isinstance(node, c_ast.TypeDecl):
            return self._get_ident_type(node.type)
        elif isinstance(node, c_ast.FuncDecl):
            return "{} (CUDA_CB *{})({})" .format(
                    self._get_ident_type(node.type),
                    node.type.declname,
                    self._stringify_params(node.args.params))
        else:
            return ' '.join(node.names)

    def _stringify_param(self, param):
        param_type = param.type
        result = self._get_quals_string(param)
        result += self._get_ident_type(param_type)

        if isinstance(param_type, c_ast.TypeDecl):
            param_type_type = param_type.type
            if isinstance(param_type_type, c_ast.Struct):
                if param_type_type.name:
                    self.indent += 1
                    result += " {\n" + self._stringify_struct(param_type_type) +\
                               ("  " * (self.indent - 1) + "}")
                    self.indent -= 1

        if param.name:
            result += ' ' + param.name

        if isinstance(param_type, c_ast.ArrayDecl):
            # TODO(sergey): Workaround to deal with the
            # preprocessed file where array size got
            # substituded.
            dim = param_type.dim.value
            if param.name == "reserved" and dim == "64":
                dim = "CU_IPC_HANDLE_SIZE"
            result += '[' + dim + ']'
        return result

    def _stringify_params(self, params):
        result = []
        for param in params:
            result.append(self._stringify_param(param))
        return ', '.join(result)

    def _stringify_struct(self, node):
        result = ""
        children = node.children()
        for child in children:
            member = self._stringify_param(child[1])
            result += ("  " * self.indent) + member + ";\n"
        return result

    def _stringify_enum(self, node):
        result = ""
        children = node.children()
        for child in children:
            if isinstance(child[1], c_ast.EnumeratorList):
                enumerators = child[1].enumerators
                for enumerator in enumerators:
                    result += ("  " * self.indent) + enumerator.name
                    value = enumerator.value
                    value_type = value.__class__.__name__
                    if value_type == "Constant":
                        result += " = " + value.value
                    elif value_type == "BinaryOp":
                        result += " = ({} {} {})".format(value.left.value,
                                                         value.op,
                                                         value.right.value)
                    result += ",\n"
                    if enumerator.name.startswith("CUDA_ERROR_"):
                        ERRORS.append(enumerator.name)
        return result

    def visit_Decl(self, node):
        if node.type.__class__.__name__ == 'FuncDecl':
            if isinstance(node.type, c_ast.FuncDecl):
                func_decl = node.type
                func_decl_type = func_decl.type

                typedef = 'typedef '
                symbol_name = None

                if isinstance(func_decl_type, c_ast.TypeDecl):
                    symbol_name = func_decl_type.declname
                    typedef += self._get_quals_string(func_decl_type)
                    typedef += self._get_ident_type(func_decl_type.type)
                    typedef += ' CUDAAPI'
                    typedef += ' t' + symbol_name
                elif isinstance(func_decl_type, c_ast.PtrDecl):
                    ptr_type = func_decl_type.type
                    symbol_name = ptr_type.declname
                    typedef += self._get_quals_string(ptr_type)
                    typedef += self._get_ident_type(func_decl_type)
                    typedef += ' CUDAAPI'
                    typedef += ' t' + symbol_name

                typedef += '(' + \
                    self._stringify_params(func_decl.args.params) + \
                    ');'

                SYMBOLS.append(symbol_name)
                FUNC_TYPEDEFS.append(typedef)

    def visit_Typedef(self, node):
        if node.name in self.dummy_typedefs:
            return

        complex = False
        type = self._get_ident_type(node.type)
        quals = self._get_quals_string(node)

        if isinstance(node.type.type, c_ast.Struct):
            self.indent += 1
            struct = self._stringify_struct(node.type.type)
            self.indent -= 1
            typedef = quals + type + " {\n" + struct + "} " + node.name
            complex = True
        elif isinstance(node.type.type, c_ast.Enum):
            self.indent += 1
            enum = self._stringify_enum(node.type.type)
            self.indent -= 1
            typedef = quals + type + " {\n" + enum + "} " + node.name
            complex = True
        elif isinstance(node.type.type, c_ast.FuncDecl):
            typedef = type
        else:
            typedef = quals + type + " " + node.name
        if complex or self.prev_complex:
            typedef = "\ntypedef " + typedef + ";"
        else:
            typedef = "typedef " + typedef + ";"

        TYPEDEFS.append(typedef)

        self.prev_complex = complex


def get_latest_cpp():
    path_prefix = "/usr/bin"
    for major in ("9", "8", "7", "6", "5", "4"):
        for minor in (".9", ".8", ".7", ".6", ".5", ".4", ".3", ".2", ".1", ""):
            test_cpp = os.path.join(path_prefix, "cpp-{}".format(major, minor))
            if os.path.exists(test_cpp):
                return test_cpp
    default_cpp = os.path.join(path_prefix, "cpp")
    if os.path.exists(default_cpp):
        return default_cpp
    return None


def preprocess_file(filename, cpp_path):
    args = [cpp_path, "-I./"]
    if filename.endswith("GL.h"):
        args.append("-DCUDAAPI= ")
    args.append(filename)

    try:
        pipe = Popen(args,
                     stdout=PIPE,
                     universal_newlines=True)
        text = pipe.communicate()[0]
    except OSError as e:
        raise RuntimeError("Unable to invoke 'cpp'.  " +
            'Make sure its path was passed correctly\n' +
            ('Original error: %s' % e))

    return text


def parse_files():
    parser = c_parser.CParser()
    cpp_path = get_latest_cpp()

    for filename in FILES:
        filepath = os.path.join(INCLUDE_DIR, filename)
        dummy_typedefs = {}
        text = preprocess_file(filepath, cpp_path)

        if filepath.endswith("GL.h"):
            dummy_typedefs = {
                "CUresult": "int",
                "CUgraphicsResource": "void *",
                "CUdevice": "void *",
                "CUcontext": "void *",
                "CUdeviceptr": "void *",
                "CUstream": "void *"
                }

            text = "typedef int GLint;\n" + text
            text = "typedef unsigned int GLuint;\n" + text
            text = "typedef unsigned int GLenum;\n" + text
            text = "typedef long size_t;\n" + text

        for typedef in sorted(dummy_typedefs):
            text = "typedef " + dummy_typedefs[typedef] + " " + \
                typedef + ";\n" + text

        ast = parser.parse(text, filepath)

        with open(filepath) as f:
            lines = f.readlines()
            for line in lines:
                if line.startswith("#define"):
                    line = line[8:-1]
                    token = line.split()
                    if token[0] not in ("__cuda_cuda_h__",
                                        "CUDA_CB",
                                        "CUDAAPI",
                                        "CUDAGL_H",
                                        "__NVRTC_H__"):
                        DEFINES.append(token)

            for line in lines:
                # TODO(sergey): Use better matching rule for _v2 symbols.
                if line[0].isspace() and line.lstrip().startswith("#define"):
                    line = line[12:-1]
                    token = line.split()
                    if len(token) == 2 and (token[1].endswith("_v2") or
                                            token[1].endswith("_v2)")):
                        if token[1].startswith('__CUDA_API_PTDS') or \
                           token[1].startswith('__CUDA_API_PTSZ'):
                            token[1] = token[1][16:-1]
                        DEFINES_V2.append(token)

        v = FuncDefVisitor()
        for typedef in dummy_typedefs:
            v.dummy_typedefs.append(typedef)
        v.visit(ast)

        FUNC_TYPEDEFS.append('')
        SYMBOLS.append('')


def print_header():
    source = open("cuew.template.h", "r").read()

    defines = ''
    for define in DEFINES:
        defines += '#define %s\n' % (' '.join(define))

    defines_v2 = ''
    for define in DEFINES_V2:
        defines_v2 += '#define %s\n' % (' '.join(define))

    typedefs = ''
    for typedef in TYPEDEFS:
        typedefs += '%s\n' % (typedef)

    func_typedefs = ''
    for func_typedef in FUNC_TYPEDEFS:
        func_typedefs += '%s\n' % (func_typedef)

    func_declarations = ''
    for symbol in SYMBOLS:
        if symbol:
            func_declarations += 'extern t%s *%s;\n' % (symbol, symbol)
        else:
            func_declarations += '\n'

    source = source.replace('%DEFINES%', defines.rstrip())
    source = source.replace('%DEFINES_V2%', defines_v2.rstrip())
    source = source.replace('%TYPEDEFS%', typedefs.rstrip())
    source = source.replace('%FUNC_TYPEDEFS%', func_typedefs.rstrip())
    source = source.replace('%FUNC_DECLARATIONS%', func_declarations.rstrip())

    sys.stdout.write(source)


def print_implementation():
    source = open("cuew.template.c", "r").read()

    function_definitions = ''
    for symbol in SYMBOLS:
        if symbol:
            function_definitions += 't%s *%s;\n' % (symbol, symbol)
        else:
            function_definitions += '\n'

    cuda_errors = ''
    for error in ERRORS:
        if error in CUDA_ERRORS:
            str = CUDA_ERRORS[error]
        else:
            temp = error[11:].replace('_', ' ')
            str = temp[0] + temp[1:].lower()
        cuda_errors += "    case %s: return \"%s\";\n" % (error, str)

    lib_find_cuda = ''
    for symbol in SYMBOLS:
        if symbol:
          if not symbol.startswith('nvrtc'):
            lib_find_cuda += "  CUDA_LIBRARY_FIND(%s);\n" % (symbol)
        else:
            lib_find_cuda += "\n"

    lib_find_nvrtc = ''
    for symbol in SYMBOLS:
        if symbol and symbol.startswith('nvrtc'):
            lib_find_nvrtc += "  NVRTC_LIBRARY_FIND(%s);\n" % (symbol)

    source = source.replace('%FUNCTION_DEFINITIONS%', function_definitions.rstrip())
    source = source.replace('%CUDA_ERRORS%', cuda_errors.rstrip())
    source = source.replace('%LIB_FIND_CUDA%', lib_find_cuda.rstrip())
    source = source.replace('%LIB_FIND_NVRTC%', lib_find_nvrtc.rstrip())

    sys.stdout.write(source)


if __name__ == "__main__":

    if len(sys.argv) != 2 and len(sys.argv) != 3:
        print("Usage: %s hdr|impl [/path/to/cuda/toolkit/include]" %
              (sys.argv[0]))
        exit(1)

    if len(sys.argv) == 3:
        INCLUDE_DIR = sys.argv[2]

    parse_files()

    if sys.argv[1] == "hdr":
        print_header()
    elif sys.argv[1] == "impl":
        print_implementation()
    else:
        print("Unknown command %s" % (sys.argv[1]))
        exit(1)
