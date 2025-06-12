.text
.global kernel_func
.p2align 8
.type kernel_func,@function

.set s_A,       12
.set s_i_per_block,    16
.set s_iter, 17
.set s_tmp,     16
.set s_accum,   8
.set UNROLL,     4
.set BLOCK_SIZE, 1024

kernel_func:
    s_load_dwordx4         s[s_A:s_A+3], s[0:1], 0
    s_load_dword           s[s_i_per_block], s[0:1], 16
    s_load_dword           s[s_iter], s[0:1], 20
    s_waitcnt              lgkmcnt(0)
    # blockIdx.x will be in s2
    # we assume every iteration contains UNROLL vector reads
    
    s_mul_i32 s2, s2, s[s_i_per_block] ; current
    v_add_u32_e32 v0, s2, v0 ; current + offset
    v_mov_b32_e32 v1, 0
    v_mov_b32_e32 v2, BLOCK_SIZE
    v_mov_b32_e32 v3, 0
    v_mov_b32_e32 v[s_accum], 0
    v_mov_b32_e32 v[s_accum+1], 0
    v_mov_b32_e32 v[s_accum+2], 0
    v_mov_b32_e32 v[s_accum+3], 0

    s_cmp_lt_i32 s[s_iter], 1
    s_cbranch_scc1 .EXIT

.UNROLLED_LOOP:
    .cnt=0
    .rept UNROLL
        v_lshl_add_u32 v[s_tmp + .cnt], v0, 4, 0 ; move to the next vec4 (+16 bytes)
        buffer_load_dwordx4 v[s_tmp + .cnt + 2:s_tmp + .cnt + 5], v[s_tmp + .cnt], s[s_A:s_A+3], 0 offen
        v_lshl_add_u32 v0, v0, 0, v2 ; offs += BLOCK_SIZE
        .cnt = .cnt + 6
    .endr

    .wait_no = UNROLL-1
    .cnt = 2
    .rept UNROLL
      # wait for the first load
      s_waitcnt vmcnt(.wait_no)
      v_pk_add_f32 v[s_accum : s_accum+1], v[s_accum : s_accum+1], v[s_tmp+.cnt: s_tmp+.cnt+1]
      v_pk_add_f32 v[s_accum+2:s_accum+3], v[s_accum+2:s_accum+3], v[s_tmp+.cnt+2:s_tmp+.cnt+3]
     .wait_no = .wait_no-1
     .cnt = .cnt+6
    .endr

    s_add_i32 s[s_iter], s[s_iter], -1
    s_cmp_gt_i32 s[s_iter], 0
    s_cbranch_scc1 .UNROLLED_LOOP

.EXIT:
    s_endpgm

.rodata
.p2align 6
.amdhsa_kernel kernel_func
    .amdhsa_group_segment_fixed_size 65536
    .amdhsa_user_sgpr_kernarg_segment_ptr 1
    .amdhsa_system_sgpr_workgroup_id_x 1
    .amdhsa_system_vgpr_workitem_id 0
    .amdhsa_next_free_vgpr 64
    .amdhsa_next_free_sgpr 32
    .amdhsa_accum_offset 32
    .amdhsa_ieee_mode 0
    .amdhsa_dx10_clamp 0
.end_amdhsa_kernel

.amdgpu_metadata
---
amdhsa.version: [ 1, 0 ]
amdhsa.kernels:
  - .name: kernel_func
    .symbol: kernel_func.kd
    .sgpr_count: 32
    .vgpr_count: 64
    .kernarg_segment_align: 4
    .kernarg_segment_size: 24
    .group_segment_fixed_size: 65536
    .private_segment_fixed_size: 0
    .wavefront_size: 64
    .reqd_workgroup_size : [1024, 1, 1]
    .max_flat_workgroup_size: 1024
    .args:
    - { .name: A,   .size: 8, .offset:   0, .value_kind: global_buffer, .value_type: f32, .address_space: global, .is_const: true}
    - { .name: size,   .size: 4, .offset:   8, .value_kind: by_value, .value_type: u32}
    - { .name: flags,   .size: 4, .offset:   12, .value_kind: by_value, .value_type: u32}
    - { .name: issues_per_block, .size: 4, .offset:   16, .value_kind: by_value, .value_type: u32}
    - { .name: iter,  .size: 4, .offset:   20, .value_kind: by_value, .value_type: u32}
...
.end_amdgpu_metadata

