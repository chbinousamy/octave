////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2023 The Octave Project Developers
//
// See the file COPYRIGHT.md in the top-level directory of this
// distribution or <https://octave.org/copyright/>.
//
// This file is part of Octave.
//
// Octave is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Octave is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Octave; see the file COPYING.  If not, see
// <https://www.gnu.org/licenses/>.
//
////////////////////////////////////////////////////////////////////////

#if ! defined (octave_pt_bytecode_h)
#define octave_pt_bytecode_h 1

#include <vector>
#include <map>

#include "octave-config.h"
#include "Cell.h"
#include "ov-vm.h"

OCTAVE_BEGIN_NAMESPACE(octave)

class tree;

enum class INSTR
{
  POP,
  DUP,
  LOAD_CST,
  MUL,
  DIV,
  ADD,
  SUB,
  RET,
  ASSIGN,
  JMP_IF,
  JMP,
  JMP_IFN,
  PUSH_SLOT_NARGOUT0,
  LE,
  LE_EQ,
  GR,
  GR_EQ,
  EQ,
  NEQ,
  INDEX_ID_NARGOUT0,
  PUSH_SLOT_INDEXED,
  POW,
  LDIV,
  EL_MUL,
  EL_DIV,
  EL_POW,
  EL_AND,
  EL_OR,
  EL_LDIV,
  NOT,
  UADD,
  USUB,
  TRANS,
  HERM,
  // TODO: These should have an inplace optimization (no push)
  INCR_ID_PREFIX,
  DECR_ID_PREFIX,
  INCR_ID_POSTFIX,
  DECR_ID_POSTFIX,
  FOR_SETUP,
  FOR_COND,
  POP_N_INTS,
  PUSH_SLOT_NARGOUT1,
  INDEX_ID_NARGOUT1,
  PUSH_FCN_HANDLE,
  COLON3,
  COLON2,
  COLON3_CMD,
  COLON2_CMD,
  PUSH_TRUE,
  PUSH_FALSE,
  UNARY_TRUE,
  INDEX_IDN,
  ASSIGNN,
  PUSH_SLOT_NARGOUTN,
  SUBASSIGN_ID,
  END_ID,
  MATRIX,
  TRANS_MUL,
  MUL_TRANS,
  HERM_MUL,
  MUL_HERM,
  TRANS_LDIV,
  HERM_LDIV,
  WORDCMD,
  HANDLE_SIGNALS,
  PUSH_CELL,
  PUSH_OV_U64,
  EXPAND_CS_LIST,
  INDEX_CELL_ID_NARGOUT0,
  INDEX_CELL_ID_NARGOUT1,
  INDEX_CELL_ID_NARGOUTN,
  INCR_PREFIX,
  ROT,
  GLOBAL_INIT,
  ASSIGN_COMPOUND,
  JMP_IFDEF,
  JMP_IFNCASEMATCH,
  BRAINDEAD_PRECONDITION,
  BRAINDEAD_WARNING,
  FORCE_ASSIGN, // Accepts undefined rhs
  PUSH_NIL,
  THROW_IFERROBJ,
  INDEX_STRUCT_NARGOUTN,
  SUBASSIGN_STRUCT,
  SUBASSIGN_CELL_ID,
  INDEX_OBJ,
  SUBASSIGN_OBJ,
  MATRIX_UNEVEN,
  LOAD_FAR_CST,
  END_OBJ,
  SET_IGNORE_OUTPUTS,
  CLEAR_IGNORE_OUTPUTS,
  SUBASSIGN_CHAINED,
  SET_SLOT_TO_STACK_DEPTH,
  DUPN,
  DEBUG,
  INDEX_STRUCT_CALL,
  END_X_N,
  EVAL,
  BIND_ANS,
  PUSH_ANON_FCN_HANDLE,
  FOR_COMPLEX_SETUP, // opcode
  FOR_COMPLEX_COND,
  PUSH_SLOT_NARGOUT1_SPECIAL,
  DISP,
  PUSH_SLOT_DISP,
  LOAD_CST_ALT2,
  LOAD_CST_ALT3,
  LOAD_CST_ALT4,
  LOAD_2_CST,
  MUL_DBL,
  ADD_DBL,
  SUB_DBL,
  DIV_DBL,
  POW_DBL,
  LE_DBL,
  LE_EQ_DBL,
  GR_DBL,
  GR_EQ_DBL,
  EQ_DBL,
  NEQ_DBL,
  INDEX_ID1_MAT_1D,
  INDEX_ID1_MAT_2D,
  PUSH_PI,
  INDEX_ID1_MATHY_UFUN,
  SUBASSIGN_ID_MAT_1D,
  INCR_ID_PREFIX_DBL,
  DECR_ID_PREFIX_DBL,
  INCR_ID_POSTFIX_DBL,
  DECR_ID_POSTFIX_DBL,
  PUSH_DBL_0,
  PUSH_DBL_1,
  PUSH_DBL_2,
  JMP_IF_BOOL,
  JMP_IFN_BOOL,
  USUB_DBL,
  NOT_DBL,
  NOT_BOOL,
  PUSH_FOLDED_CST,
  SET_FOLDED_CST,
  WIDE,
};

enum class unwind_entry_type
{
  INVALID,
  FOR_LOOP,
  TRY_CATCH,
  UNWIND_PROTECT,
};

struct unwind_entry
{
  int m_ip_start;
  int m_ip_end;
  int m_ip_target;
  int m_stack_depth;
  unwind_entry_type m_unwind_entry_type;
};

struct loc_entry
{
  int m_ip_start = -1;
  int m_ip_end = -1;
  int m_col = -1;
  int m_line = -1;
};

struct arg_name_entry
{
  int m_ip_start;
  int m_ip_end;
  Cell m_arg_names;
  std::string m_obj_name;
};

struct unwind_data
{
  std::vector<unwind_entry> m_unwind_entries;
  std::vector<loc_entry> m_loc_entry;
  std::map<int, int> m_slot_to_persistent_slot;
  std::map<int, tree*> m_ip_to_tree;
  std::vector<arg_name_entry> m_argname_entries;
  std::map<int,int> m_external_frame_offset_to_internal;

  std::string m_name;
  std::string m_file;

  unsigned m_code_size;
  unsigned m_ids_size;
};

struct bytecode
{
  std::vector<unsigned char> m_code;
  std::vector<octave_value> m_data;
  std::vector<std::string> m_ids;
  unwind_data m_unwind_data;
};

union stack_element
{
  octave_value ov;
  octave_value_vm ov_vm;
  octave_base_value *ovb;
  uint64_t u;
  int64_t i;
  double d;

  void *pv;
  const char *pcc;
  unsigned char *puc;
  stack_element *pse;
  octave_value *pov;
  std::string *ps;
  unwind_data *pud;
  execution_exception *pee;

  stack_element(){}
  ~stack_element(){}
};

// Enums to describe what error message to build
enum class error_type
{
  INVALID,
  ID_UNDEFINED,
  ID_UNDEFINEDN,
  IF_UNDEFINED,
  INDEX_ERROR,
  EXECUTION_EXC,
  INTERRUPT_EXC,
  INVALID_N_EL_RHS_IN_ASSIGNMENT,
  RHS_UNDEF_IN_ASSIGNMENT,
  BAD_ALLOC,
  EXIT_EXCEPTION,
};

enum class global_type
{
  GLOBAL,
  PERSISTENT,
  GLOBAL_OR_PERSISTENT,
};

// If TRUE, use VM evaluator rather than tree walker.
extern bool V__enable_vm_eval__;

OCTAVE_END_NAMESPACE(octave)

#endif
