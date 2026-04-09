/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/math_util.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_math(ccl_private float *ccl_restrict stack,
                                       const ccl_global SVMNodeMath &ccl_restrict node)
{
  const float a = stack_load(stack, node.value1);
  const float b = stack_load(stack, node.value2);
  const float c = stack_load(stack, node.value3);
  const float result = svm_math(node.math_type, a, b, c);

  stack_store_float(stack, node.result_offset, result);
}

template<typename Float3Type>
ccl_device_noinline void svm_node_vector_math(
    ccl_private float *ccl_restrict stack, const ccl_global SVMNodeVectorMath &ccl_restrict node)
{
  using FloatType = dual_scalar_t<Float3Type>;

  const Float3Type a = stack_load<Float3Type>(stack, node.a);
  const Float3Type b = stack_load<Float3Type>(stack, node.b);
  const Float3Type c = stack_load<Float3Type>(stack, node.c);
  const FloatType param1 = stack_load<FloatType>(stack, node.param1);

  FloatType value = make_zero<FloatType>();
  Float3Type vector = make_zero<Float3Type>();
  svm_vector_math(&value, &vector, node.math_type, a, b, c, param1);

  if (stack_valid(node.value_offset)) {
    stack_store(stack, node.value_offset, value);
  }
  if (stack_valid(node.vector_offset)) {
    stack_store(stack, node.vector_offset, vector);
  }
}

CCL_NAMESPACE_END
