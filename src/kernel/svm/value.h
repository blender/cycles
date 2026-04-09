/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Value Nodes */

template<typename FloatType>
ccl_device void svm_node_value_f(ccl_private float *ccl_restrict stack,
                                 const ccl_global SVMNodeValueF &ccl_restrict node)
{
  /* Derivative of a constant is zero. */
  stack_store(stack, node.out_offset, FloatType(node.value));
}

template<typename Float3Type>
ccl_device void svm_node_value_v(ccl_private float *ccl_restrict stack,
                                 const ccl_global SVMNodeValueV &ccl_restrict node)
{
  /* Derivative of a constant is zero. */
  stack_store(stack, node.out_offset, Float3Type(node.value));
}

CCL_NAMESPACE_END
