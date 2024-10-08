// RUN: mlir-opt -split-input-file -allow-unregistered-dialect -affine-loop-coalescing --cse %s | FileCheck %s

// CHECK-LABEL: @one_3d_nest
func.func @one_3d_nest() {
  // Capture original bounds.  Note that for zero-based step-one loops, the
  // upper bound is also the number of iterations.
  // CHECK: %[[orig_lb:.*]] = arith.constant 0
  // CHECK: %[[orig_step:.*]] = arith.constant 1
  // CHECK: %[[orig_ub_k:.*]] = arith.constant 3
  // CHECK: %[[orig_ub_i:.*]] = arith.constant 42
  // CHECK: %[[orig_ub_j:.*]] = arith.constant 56
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  %c3 = arith.constant 3 : index
  %c42 = arith.constant 42 : index
  %c56 = arith.constant 56 : index
  // The range of the new scf.
  // CHECK:     %[[partial_range:.*]] = arith.muli %[[orig_ub_i]], %[[orig_ub_j]]
  // CHECK-NEXT:%[[range:.*]] = arith.muli %[[partial_range]], %[[orig_ub_k]]

  // Updated loop bounds.
  // CHECK: scf.for %[[i:.*]] = %[[orig_lb]] to %[[range]] step %[[orig_step]]
  scf.for %i = %c0 to %c42 step %c1 {
    // Inner loops must have been removed.
    // CHECK-NOT: scf.for

    // Reconstruct original IVs from the linearized one.
    // CHECK: %[[orig_k:.*]] = arith.remsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[div:.*]] = arith.divsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[orig_j:.*]] = arith.remsi %[[div]], %[[orig_ub_j]]
    // CHECK: %[[orig_i:.*]] = arith.divsi %[[div]], %[[orig_ub_j]]
    scf.for %j = %c0 to %c56 step %c1 {
      scf.for %k = %c0 to %c3 step %c1 {
        // CHECK: "use"(%[[orig_i]], %[[orig_j]], %[[orig_k]])
        "use"(%i, %j, %k) : (index, index, index) -> ()
      }
    }
  }
  return
}

// Check that there is no chasing the replacement of value uses by ensuring
// multiple uses of loop induction variables get rewritten to the same values.

// CHECK-LABEL: @multi_use
func.func @multi_use() {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c10 = arith.constant 10 : index
  // CHECK: scf.for %[[iv:.*]] =
  scf.for %i = %c1 to %c10 step %c1 {
    scf.for %j = %c1 to %c10 step %c1 {
      scf.for %k = %c1 to %c10 step %c1 {
        // CHECK: %[[k_unshifted:.*]] = arith.remsi %[[iv]], %[[k_extent:.*]]
        // CHECK: %[[ij:.*]] = arith.divsi %[[iv]], %[[k_extent]]
        // CHECK: %[[j_unshifted:.*]] = arith.remsi %[[ij]], %[[j_extent:.*]]
        // CHECK: %[[i_unshifted:.*]] = arith.divsi %[[ij]], %[[j_extent]]
        // CHECK: %[[k:.*]] = arith.addi %[[k_unshifted]]
        // CHECK: %[[j:.*]] = arith.addi %[[j_unshifted]]
        // CHECK: %[[i:.*]] = arith.addi %[[i_unshifted]]

        // CHECK: "use1"(%[[i]], %[[j]], %[[k]])
        "use1"(%i,%j,%k) : (index,index,index) -> ()
        // CHECK: "use2"(%[[i]], %[[k]], %[[j]])
        "use2"(%i,%k,%j) : (index,index,index) -> ()
        // CHECK: "use3"(%[[k]], %[[j]], %[[i]])
        "use3"(%k,%j,%i) : (index,index,index) -> ()
      }
    }
  }
  return
}

func.func @unnormalized_loops() {
  // CHECK: %[[orig_step_i:.*]] = arith.constant 2

  // CHECK: %[[orig_step_j_and_numiter_i:.*]] = arith.constant 3
  // CHECK: %[[orig_lb_i:.*]] = arith.constant 5
  // CHECK: %[[orig_lb_j:.*]] = arith.constant 7
  %c2 = arith.constant 2 : index
  %c3 = arith.constant 3 : index
  %c5 = arith.constant 5 : index
  %c7 = arith.constant 7 : index
  %c10 = arith.constant 10 : index
  %c17 = arith.constant 17 : index

  // Normalized lower bound and step for the outer scf.
  // CHECK: %[[lb_i:.*]] = arith.constant 0
  // CHECK: %[[step_i:.*]] = arith.constant 1

  // Number of iterations in the inner loop, the pattern is the same as above,
  // only capture the final result.
  // CHECK: %[[numiter_j:.*]] = arith.constant 4

  // New bounds of the outer scf.
  // CHECK: %[[range:.*]] = arith.muli %[[orig_step_j_and_numiter_i:.*]], %[[numiter_j]]
  // CHECK: scf.for %[[i:.*]] = %[[lb_i]] to %[[range]] step %[[step_i]]
  scf.for %i = %c5 to %c10 step %c2 {
    // The inner loop has been removed.
    // CHECK-NOT: scf.for
    scf.for %j = %c7 to %c17 step %c3 {
      // The IVs are rewritten.
      // CHECK: %[[normalized_j:.*]] = arith.remsi %[[i]], %[[numiter_j]]
      // CHECK: %[[normalized_i:.*]] = arith.divsi %[[i]], %[[numiter_j]]
      // CHECK: %[[scaled_j:.*]] = arith.muli %[[normalized_j]], %[[orig_step_j_and_numiter_i]]
      // CHECK: %[[orig_j:.*]] = arith.addi %[[scaled_j]], %[[orig_lb_j]]
      // CHECK: %[[scaled_i:.*]] = arith.muli %[[normalized_i]], %[[orig_step_i]]
      // CHECK: %[[orig_i:.*]] = arith.addi %[[scaled_i]], %[[orig_lb_i]]
      // CHECK: "use"(%[[orig_i]], %[[orig_j]])
      "use"(%i, %j) : (index, index) -> ()
    }
  }
  return
}

func.func @noramalized_loops_with_yielded_iter_args() {
  // CHECK: %[[orig_lb:.*]] = arith.constant 0
  // CHECK: %[[orig_step:.*]] = arith.constant 1
  // CHECK: %[[orig_ub_k:.*]] = arith.constant 3
  // CHECK: %[[orig_ub_i:.*]] = arith.constant 42
  // CHECK: %[[orig_ub_j:.*]] = arith.constant 56
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  %c42 = arith.constant 42 : index
  %c56 = arith.constant 56 : index
  // The range of the new scf.
  // CHECK:     %[[partial_range:.*]] = arith.muli %[[orig_ub_i]], %[[orig_ub_j]]
  // CHECK-NEXT:%[[range:.*]] = arith.muli %[[partial_range]], %[[orig_ub_k]]

  // Updated loop bounds.
  // CHECK: scf.for %[[i:.*]] = %[[orig_lb]] to %[[range]] step %[[orig_step]] iter_args(%[[VAL_1:.*]] = %[[orig_lb]]) -> (index) {
  %2:1 = scf.for %i = %c0 to %c42 step %c1 iter_args(%arg0 = %c0) -> (index) {
    // Inner loops must have been removed.
    // CHECK-NOT: scf.for

    // Reconstruct original IVs from the linearized one.
    // CHECK: %[[orig_k:.*]] = arith.remsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[div:.*]] = arith.divsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[orig_j:.*]] = arith.remsi %[[div]], %[[orig_ub_j]]
    // CHECK: %[[orig_i:.*]] = arith.divsi %[[div]], %[[orig_ub_j]]
    %1:1 = scf.for %j = %c0 to %c56 step %c1 iter_args(%arg1 = %arg0) -> (index){
      %0:1 = scf.for %k = %c0 to %c3 step %c1 iter_args(%arg2 = %arg1) -> (index) {
        // CHECK: "use"(%[[orig_i]], %[[orig_j]], %[[orig_k]])
        "use"(%i, %j, %k) : (index, index, index) -> ()
        // CHECK: scf.yield %[[VAL_1]] : index
        scf.yield %arg2 : index
      }
      scf.yield %0#0 : index
    }
    scf.yield %1#0 : index
  }
  return
}

func.func @noramalized_loops_with_shuffled_yielded_iter_args() {
  // CHECK: %[[orig_lb:.*]] = arith.constant 0
  // CHECK: %[[orig_step:.*]] = arith.constant 1
  // CHECK: %[[orig_ub_k:.*]] = arith.constant 3
  // CHECK: %[[orig_ub_i:.*]] = arith.constant 42
  // CHECK: %[[orig_ub_j:.*]] = arith.constant 56
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  %c42 = arith.constant 42 : index
  %c56 = arith.constant 56 : index
  // The range of the new scf.
  // CHECK:     %[[partial_range:.*]] = arith.muli %[[orig_ub_i]], %[[orig_ub_j]]
  // CHECK-NEXT:%[[range:.*]] = arith.muli %[[partial_range]], %[[orig_ub_k]]

  // Updated loop bounds.
  // CHECK: scf.for %[[i:.*]] = %[[orig_lb]] to %[[range]] step %[[orig_step]] iter_args(%[[VAL_1:.*]] = %[[orig_lb]], %[[VAL_2:.*]] = %[[orig_lb]]) -> (index, index) {
  %2:2 = scf.for %i = %c0 to %c42 step %c1 iter_args(%arg0 = %c0, %arg1 = %c0) -> (index, index) {
    // Inner loops must have been removed.
    // CHECK-NOT: scf.for

    // Reconstruct original IVs from the linearized one.
    // CHECK: %[[orig_k:.*]] = arith.remsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[div:.*]] = arith.divsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[orig_j:.*]] = arith.remsi %[[div]], %[[orig_ub_j]]
    // CHECK: %[[orig_i:.*]] = arith.divsi %[[div]], %[[orig_ub_j]]
    %1:2 = scf.for %j = %c0 to %c56 step %c1 iter_args(%arg2 = %arg0, %arg3 = %arg1) -> (index, index){
      %0:2 = scf.for %k = %c0 to %c3 step %c1 iter_args(%arg4 = %arg2, %arg5 = %arg3) -> (index, index) {
        // CHECK: "use"(%[[orig_i]], %[[orig_j]], %[[orig_k]])
        "use"(%i, %j, %k) : (index, index, index) -> ()
        // CHECK: scf.yield %[[VAL_2]], %[[VAL_1]] : index, index
        scf.yield %arg5, %arg4 : index, index
      }
      scf.yield %0#0, %0#1 : index, index
    }
    scf.yield %1#0, %1#1 : index, index
  }
  return
}

func.func @noramalized_loops_with_yielded_non_iter_args() {
  // CHECK: %[[orig_lb:.*]] = arith.constant 0
  // CHECK: %[[orig_step:.*]] = arith.constant 1
  // CHECK: %[[orig_ub_k:.*]] = arith.constant 3
  // CHECK: %[[orig_ub_i:.*]] = arith.constant 42
  // CHECK: %[[orig_ub_j:.*]] = arith.constant 56
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c3 = arith.constant 3 : index
  %c42 = arith.constant 42 : index
  %c56 = arith.constant 56 : index
  // The range of the new scf.
  // CHECK:     %[[partial_range:.*]] = arith.muli %[[orig_ub_i]], %[[orig_ub_j]]
  // CHECK-NEXT:%[[range:.*]] = arith.muli %[[partial_range]], %[[orig_ub_k]]

  // Updated loop bounds.
  // CHECK: scf.for %[[i:.*]] = %[[orig_lb]] to %[[range]] step %[[orig_step]] iter_args(%[[VAL_1:.*]] = %[[orig_lb]]) -> (index) {
  %2:1 = scf.for %i = %c0 to %c42 step %c1 iter_args(%arg0 = %c0) -> (index) {
    // Inner loops must have been removed.
    // CHECK-NOT: scf.for

    // Reconstruct original IVs from the linearized one.
    // CHECK: %[[orig_k:.*]] = arith.remsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[div:.*]] = arith.divsi %[[i]], %[[orig_ub_k]]
    // CHECK: %[[orig_j:.*]] = arith.remsi %[[div]], %[[orig_ub_j]]
    // CHECK: %[[orig_i:.*]] = arith.divsi %[[div]], %[[orig_ub_j]]
    %1:1 = scf.for %j = %c0 to %c56 step %c1 iter_args(%arg1 = %arg0) -> (index){
      %0:1 = scf.for %k = %c0 to %c3 step %c1 iter_args(%arg2 = %arg1) -> (index) {
        // CHECK: %[[res:.*]] = "use"(%[[orig_i]], %[[orig_j]], %[[orig_k]])
        %res = "use"(%i, %j, %k) : (index, index, index) -> (index)
        // CHECK: scf.yield %[[res]] : index
        scf.yield %res : index
      }
      scf.yield %0#0 : index
    }
    scf.yield %1#0 : index
  }
  return
}

// Check with parametric loop bounds and steps, capture the bounds here.
// CHECK-LABEL: @parametric
// CHECK-SAME: %[[orig_lb1:[A-Za-z0-9]+]]:
// CHECK-SAME: %[[orig_ub1:[A-Za-z0-9]+]]:
// CHECK-SAME: %[[orig_step1:[A-Za-z0-9]+]]:
// CHECK-SAME: %[[orig_lb2:[A-Za-z0-9]+]]:
// CHECK-SAME: %[[orig_ub2:[A-Za-z0-9]+]]:
// CHECK-SAME: %[[orig_step2:[A-Za-z0-9]+]]:
func.func @parametric(%lb1 : index, %ub1 : index, %step1 : index,
                 %lb2 : index, %ub2 : index, %step2 : index) {
  // Compute the number of iterations for each of the loops and the total
  // number of iterations.
  // CHECK: %[[range1:.*]] = arith.subi %[[orig_ub1]], %[[orig_lb1]]
  // CHECK: %[[numiter1:.*]] = arith.ceildivsi %[[range1]], %[[orig_step1]]
  // CHECK: %[[range2:.*]] = arith.subi %[[orig_ub2]], %[[orig_lb2]]
  // CHECK: %[[numiter2:.*]] = arith.ceildivsi %[[range2]], %[[orig_step2]]
  // CHECK: %[[range:.*]] = arith.muli %[[numiter1]], %[[numiter2]] : index

  // Check that the outer loop is updated.
  // CHECK: scf.for %[[i:.*]] = %c0{{.*}} to %[[range]] step %c1
  scf.for %i = %lb1 to %ub1 step %step1 {
    // Check that the inner loop is removed.
    // CHECK-NOT: scf.for
    scf.for %j = %lb2 to %ub2 step %step2 {
      // Remapping of the induction variables.
      // CHECK: %[[normalized_j:.*]] = arith.remsi %[[i]], %[[numiter2]] : index
      // CHECK: %[[normalized_i:.*]] = arith.divsi %[[i]], %[[numiter2]] : index
      // CHECK: %[[scaled_j:.*]] = arith.muli %[[normalized_j]], %[[orig_step2]]
      // CHECK: %[[orig_j:.*]] = arith.addi %[[scaled_j]], %[[orig_lb2]]
      // CHECK: %[[scaled_i:.*]] = arith.muli %[[normalized_i]], %[[orig_step1]]
      // CHECK: %[[orig_i:.*]] = arith.addi %[[scaled_i]], %[[orig_lb1]]

      // CHECK: "foo"(%[[orig_i]], %[[orig_j]])
      "foo"(%i, %j) : (index, index) -> ()
    }
  }
  return
}

// CHECK-LABEL: @two_bands
func.func @two_bands() {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c10 = arith.constant 10 : index
  // CHECK: %[[outer_range:.*]] = arith.muli
  // CHECK: scf.for %{{.*}} = %{{.*}} to %[[outer_range]]
  scf.for %i = %c0 to %c10 step %c1 {
    // Check that the "j" loop was removed and that the inner loops were
    // coalesced as well.  The preparation step for coalescing will inject the
    // subtraction operation unlike the IV remapping.
    // CHECK-NOT: scf.for
    // CHECK: arith.subi
    scf.for %j = %c0 to %c10 step %c1 {
      // The inner pair of loops is coalesced separately.
      // CHECK: scf.for
      scf.for %k = %i to %j step %c1 {
        // CHECK-NOT: scf.for
        scf.for %l = %i to %j step %c1 {
          "foo"() : () -> ()
        }
      }
    }
  }
  return
}

// -----

// Check coalescing of affine.for loops when all the loops have constant upper bound.
// CHECK-DAG: #[[SIXTEEN:.*]] = affine_map<() -> (16)>
// CHECK-DAG: #[[SIXTY_FOUR:.*]] = affine_map<() -> (64)>
// CHECK-DAG: #[[PRODUCT:.*]] = affine_map<(d0)[s0] -> (d0 * s0)>
// CHECK-DAG: #[[EIGHT:.*]] = affine_map<() -> (8)>
// CHECK-DAG: #[[MOD:.*]] = affine_map<(d0)[s0] -> (d0 mod s0)>
// CHECK-DAG: #[[DIV:.*]] = affine_map<(d0)[s0] -> (d0 floordiv s0)>
func.func @coalesce_affine_for() {
  affine.for %i = 0 to 16 {
    affine.for %j = 0 to 64 {
      affine.for %k = 0 to 8 {
        "test.foo"(%i, %j, %k) : (index, index, index) -> ()
      }
    }
  }
  return
}
// CHECK-DAG: %[[T0:.*]] = affine.apply #[[SIXTEEN]]()
// CHECK-DAG: %[[T1:.*]] = affine.apply #[[SIXTY_FOUR]]()
// CHECK-DAG: %[[T2:.*]] = affine.apply #[[PRODUCT]](%[[T0]])[%[[T1]]]
// CHECK-DAG: %[[T3:.*]] = affine.apply #[[EIGHT]]()
// CHECK-DAG: %[[T4:.*]] = affine.apply #[[PRODUCT]](%[[T2]])[%[[T3]]]
// CHECK:       affine.for %[[IV:.*]] = 0 to %[[T4]]
// CHECK-DAG:    %[[K:.*]] =  affine.apply #[[MOD]](%[[IV]])[%[[T3]]]
// CHECK-DAG:    %[[T6:.*]] = affine.apply #[[DIV]](%[[IV]])[%[[T3]]]
// CHECK-DAG:    %[[J:.*]] =  affine.apply #[[MOD]](%[[T6]])[%[[T1]]]
// CHECK-DAG:    %[[I:.*]] =  affine.apply #[[DIV]](%[[T6]])[%[[T1]]]
// CHECK-NEXT:    "test.foo"(%[[I]], %[[J]], %[[K]])
// CHECK-NEXT:  }
// CHECK-NEXT:  return

// -----

// Check coalescing of affine.for loops when all the loops have non constant upper bounds.
// CHECK-DAG: #[[IDENTITY:.*]] = affine_map<()[s0] -> (s0)>
// CHECK-DAG: #[[PRODUCT:.*]] = affine_map<(d0)[s0] -> (d0 * s0)>
// CHECK-DAG: #[[MOD:.*]] = affine_map<(d0)[s0] -> (d0 mod s0)>
// CHECK-DAG: #[[FLOOR:.*]] = affine_map<(d0)[s0] -> (d0 floordiv s0)>
func.func @coalesce_affine_for(%arg0: memref<?x?xf32>) {
  %c0 = arith.constant 0 : index
  %M = memref.dim %arg0, %c0 : memref<?x?xf32>
  %N = memref.dim %arg0, %c0 : memref<?x?xf32>
  %K = memref.dim %arg0, %c0 : memref<?x?xf32>
  affine.for %i = 0 to %M {
    affine.for %j = 0 to %N {
      affine.for %k = 0 to %K {
      "test.foo"(%i, %j, %k) : (index, index, index) -> ()
      }
    }
  }
  return
}
// CHECK: %[[DIM:.*]] = memref.dim %arg{{.*}}, %c{{.*}} : memref<?x?xf32>
// CHECK-DAG: %[[T0:.*]] = affine.apply #[[IDENTITY]]()[%[[DIM]]]
// CHECK-DAG: %[[T1:.*]] = affine.apply #[[PRODUCT]](%[[T0]])[%[[T0]]]
// CHECK-DAG: %[[T2:.*]] = affine.apply #[[PRODUCT]](%[[T1]])[%[[T0]]]
// CHECK: affine.for %[[IV:.*]] = 0 to %[[T2]]
// CHECK-DAG:    %[[K:.*]] = affine.apply #[[MOD]](%[[IV]])[%[[T0]]]
// CHECK-DAG:    %[[T9:.*]] = affine.apply #[[FLOOR]](%[[IV]])[%[[T0]]]
// CHECK-DAG:    %[[J:.*]] = affine.apply #[[MOD]](%[[T9]])[%[[T0]]]
// CHECK-DAG:    %[[I:.*]] = affine.apply #[[FLOOR]](%[[T9]])[%[[T0]]]
// CHECK-NEXT:    "test.foo"(%[[I]], %[[J]], %[[K]])
// CHECK-NEXT:  }
// CHECK-NEXT:  return

// -----

// Check coalescing of affine.for loops when some of the loop has constant upper bounds while others have nin constant upper bounds.
// CHECK-DAG: #[[IDENTITY:.*]] = affine_map<()[s0] -> (s0)>
// CHECK-DAG: #[[PRODUCT:.*]] = affine_map<(d0)[s0] -> (d0 * s0)>
// CHECK-DAG: #[[SIXTY_FOUR:.*]] = affine_map<() -> (64)>
// CHECK-DAG: #[[MOD:.*]] = affine_map<(d0)[s0] -> (d0 mod s0)>
// CHECK-DAG: #[[DIV:.*]] = affine_map<(d0)[s0] -> (d0 floordiv s0)>
func.func @coalesce_affine_for(%arg0: memref<?x?xf32>) {
  %c0 = arith.constant 0 : index
  %M = memref.dim %arg0, %c0 : memref<?x?xf32>
  %N = memref.dim %arg0, %c0 : memref<?x?xf32>
  affine.for %i = 0 to %M {
    affine.for %j = 0 to %N {
      affine.for %k = 0 to 64 {
      "test.foo"(%i, %j, %k) : (index, index, index) -> ()
      }
    }
  }
  return
}
// CHECK: %[[DIM:.*]] = memref.dim %arg{{.*}}, %c{{.*}} : memref<?x?xf32>
// CHECK-DAG: %[[T0:.*]] = affine.apply #[[IDENTITY]]()[%[[DIM]]]
// CHECK-DAG: %[[T1:.*]] = affine.apply #[[PRODUCT]](%[[T0]])[%[[T0]]]
// CHECK-DAG: %[[T2:.*]] = affine.apply #[[SIXTY_FOUR]]()
// CHECK-DAG: %[[T3:.*]] = affine.apply #[[PRODUCT]](%[[T1]])[%[[T2]]]
// CHECK: affine.for %[[IV:.*]] = 0 to %[[T3]]
// CHECK-DAG:    %[[K:.*]] = affine.apply #[[MOD]](%[[IV]])[%[[T2]]]
// CHECK-DAG:    %[[T5:.*]] = affine.apply #[[DIV]](%[[IV]])[%[[T2]]]
// CHECK-DAG:    %[[J:.*]] = affine.apply #[[MOD]](%[[T5]])[%[[T0]]]
// CHECK-DAG:    %[[I:.*]] = affine.apply #[[DIV]](%[[T5]])[%[[T0]]]
// CHECK-NEXT:    "test.foo"(%[[I]], %[[J]], %[[K]])
// CHECK-NEXT:  }
// CHECK-NEXT:  return

// -----

// Check coalescing of affine.for loops when upper bound contains multi result upper bound map.
// CHECK-DAG: #[[MAP0:.*]] = affine_map<()[s0] -> (s0, -s0)>
// CHECK-DAG: #[[IDENTITY:.*]] = affine_map<()[s0] -> (s0)>
// CHECK-DAG: #[[PRODUCT:.*]] = affine_map<(d0)[s0] -> (d0 * s0)>
// CHECK-DAG: #[[MOD:.*]] = affine_map<(d0)[s0] -> (d0 mod s0)>
// CHECK-DAG: #[[DIV:.*]] = affine_map<(d0)[s0] -> (d0 floordiv s0)>
#myMap = affine_map<()[s1] -> (s1, -s1)>
func.func @coalesce_affine_for(%arg0: memref<?x?xf32>) {
 %c0 = arith.constant 0 : index
 %M = memref.dim %arg0, %c0 : memref<?x?xf32>
 %N = memref.dim %arg0, %c0 : memref<?x?xf32>
 %K = memref.dim %arg0, %c0 : memref<?x?xf32>
 affine.for %i = 0 to min #myMap()[%M] {
   affine.for %j = 0 to %N {
     affine.for %k = 0 to %K {
     "test.foo"(%i, %j, %k) : (index, index, index) -> ()
     }
   }
 }
 return
}
// CHECK: %[[DIM:.*]] = memref.dim %arg{{.*}}, %c{{.*}} : memref<?x?xf32>
// CHECK-DAG: %[[T0:.*]] = affine.min #[[MAP0]]()[%[[DIM]]]
// CHECK-DAG: %[[T1:.*]] = affine.apply #[[IDENTITY]]()[%[[DIM]]]
// CHECK-DAG: %[[T2:.*]] = affine.apply #[[PRODUCT]](%[[T0]])[%[[T1]]]
// CHECK-DAG: %[[T3:.*]] = affine.apply #[[PRODUCT]](%[[T2]])[%[[T1]]]
// CHECK: affine.for %[[IV:.*]] = 0 to %[[T3]]
// CHECK-DAG:    %[[K:.*]] = affine.apply #[[MOD]](%[[IV]])[%[[T1]]]
// CHECK-DAG:    %[[T5:.*]] = affine.apply #[[DIV]](%[[IV]])[%[[T1]]]
// CHECK-DAG:    %[[J:.*]] = affine.apply #[[MOD]](%[[T5]])[%[[T1]]]
// CHECK-DAG:    %[[I:.*]] = affine.apply #[[DIV]](%[[T5]])[%[[T1]]]
// CHECK-NEXT:    "test.foo"(%[[I]], %[[J]], %[[K]])
// CHECK-NEXT:  }
// CHECK-NEXT:  return

// -----

// CHECK-DAG: #[[MAP0:.*]] = affine_map<(d0) -> (d0 * 110)>
// CHECK-DAG: #[[MAP1:.*]] = affine_map<(d0) -> (696, d0 * 110 + 110)>
#map0 = affine_map<(d0) -> (d0 * 110)>
#map1 = affine_map<(d0) -> (696, d0 * 110 + 110)>
func.func @test_loops_do_not_get_coalesced() {
  affine.for %i = 0 to 7 {
    affine.for %j = #map0(%i) to min #map1(%i) {
      "use"(%i, %j) : (index, index) -> ()
    }
  }
  return
}
// CHECK: affine.for %[[IV0:.*]] = 0 to 7
// CHECK-NEXT: affine.for %[[IV1:.*]] = #[[MAP0]](%[[IV0]]) to min #[[MAP1]](%[[IV0]])
// CHECK-NEXT:   "use"(%[[IV0]], %[[IV1]])
// CHECK-NEXT: }
// CHECK-NEXT: }
// CHECK-NEXT: return
