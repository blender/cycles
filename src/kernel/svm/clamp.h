/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Clamp Node */

ccl_device_noinline void svm_node_clamp(ccl_private float *ccl_restrict stack,
                                        const ccl_global SVMNodeClamp &ccl_restrict node)
{
  const float value = stack_load(stack, node.value);
  const float min = stack_load(stack, node.min);
  const float max = stack_load(stack, node.max);

  if (node.clamp_type == NODE_CLAMP_RANGE && (min > max)) {
    stack_store_float(stack, node.result_offset, clamp(value, max, min));
  }
  else {
    stack_store_float(stack, node.result_offset, clamp(value, min, max));
  }
}

CCL_NAMESPACE_END
