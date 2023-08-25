// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Package partition metadata.
//
// DO NOT EDIT THIS FILE DIRECTLY.
// It has been generated with ./util/design/gen-otp-mmap.py

package otp_ctrl_part_pkg;

  import prim_util_pkg::vbits;
  import otp_ctrl_reg_pkg::*;
  import otp_ctrl_pkg::*;

  ////////////////////////////////////
  // Scrambling Constants and Types //
  ////////////////////////////////////

  parameter int NumScrmblKeys = 3;
  parameter int NumDigestSets = 4;

  parameter int ScrmblKeySelWidth = vbits(NumScrmblKeys);
  parameter int DigestSetSelWidth = vbits(NumDigestSets);
  parameter int ConstSelWidth = (ScrmblKeySelWidth > DigestSetSelWidth) ?
                                ScrmblKeySelWidth :
                                DigestSetSelWidth;

  typedef enum logic [ConstSelWidth-1:0] {
    StandardMode,
    ChainedMode
  } digest_mode_e;

  typedef logic [NumScrmblKeys-1:0][ScrmblKeyWidth-1:0] key_array_t;
  typedef logic [NumDigestSets-1:0][ScrmblKeyWidth-1:0] digest_const_array_t;
  typedef logic [NumDigestSets-1:0][ScrmblBlockWidth-1:0] digest_iv_array_t;

  typedef enum logic [ConstSelWidth-1:0] {
    Secret0Key,
    Secret1Key,
    Secret2Key
  } key_sel_e;

  typedef enum logic [ConstSelWidth-1:0] {
    CnstyDigest,
    FlashDataKey,
    FlashAddrKey,
    SramDataKey
  } digest_sel_e;

  // SEC_CM: SECRET.MEM.SCRAMBLE
  parameter key_array_t RndCnstKey = {
    128'h64824C61F1EB6AB6879F8EFA78522377,
    128'hA421AEC54CAB821DF597822E4B39C87C,
    128'h9C274174149E2B57DAEE5A6398EA3A04
  };

  // SEC_CM: PART.MEM.DIGEST
  // Note: digest set 0 is used for computing the partition digests. Constants at
  // higher indices are used to compute the scrambling keys.
  parameter digest_const_array_t RndCnstDigestConst = {
    128'h5F2C075769000C39CDA36EAB93CD263D,
    128'hA824CFA99A1E179488280A4961B1644D,
    128'h26CE77C1EF8AB1D5E029DA11526F75B,
    128'h30FAA0C47E3809585A24109FBC53E920
  };

  parameter digest_iv_array_t RndCnstDigestIV = {
    64'hF2DAE31D857D1D39,
    64'h6AFB25D55069C52B,
    64'hB198D9A2A7D9B85,
    64'hAF12B341A53780AB
  };


  /////////////////////////////////////
  // Typedefs for Partition Metadata //
  /////////////////////////////////////

  typedef enum logic [1:0] {
    Unbuffered,
    Buffered,
    LifeCycle
  } part_variant_e;

  typedef struct packed {
    part_variant_e variant;
    // Offset and size within the OTP array, in Bytes.
    logic [OtpByteAddrWidth-1:0] offset;
    logic [OtpByteAddrWidth-1:0] size;
    // Key index to use for scrambling.
    key_sel_e key_sel;
    // Attributes
    logic secret;     // Whether the partition is secret (and hence scrambled)
    logic sw_digest;  // Whether the partition has a software digest
    logic hw_digest;  // Whether the partition has a hardware digest
    logic write_lock; // Whether the partition is write lockable (via digest)
    logic read_lock;  // Whether the partition is read lockable (via digest)
    logic integrity;  // Whether the partition is integrity protected
  } part_info_t;

  parameter part_info_t PartInfoDefault = '{
      variant:    Unbuffered,
      offset:     '0,
      size:       OtpByteAddrWidth'('hFF),
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b0,
      hw_digest:  1'b0,
      write_lock: 1'b0,
      read_lock:  1'b0,
      integrity:  1'b0
  };

  ////////////////////////
  // Partition Metadata //
  ////////////////////////

  localparam part_info_t PartInfo [NumPart] = '{
    // VENDOR_TEST
    '{
      variant:    Unbuffered,
      offset:     14'd0,
      size:       64,
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b1,
      hw_digest:  1'b0,
      write_lock: 1'b1,
      read_lock:  1'b0,
      integrity:  1'b0
    },
    // CREATOR_SW_CFG
    '{
      variant:    Unbuffered,
      offset:     14'd64,
      size:       768,
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b1,
      hw_digest:  1'b0,
      write_lock: 1'b1,
      read_lock:  1'b0,
      integrity:  1'b1
    },
    // OWNER_SW_CFG
    '{
      variant:    Unbuffered,
      offset:     14'd832,
      size:       768,
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b1,
      hw_digest:  1'b0,
      write_lock: 1'b1,
      read_lock:  1'b0,
      integrity:  1'b1
    },
    // HW_CFG0
    '{
      variant:    Buffered,
      offset:     14'd1600,
      size:       72,
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b0,
      hw_digest:  1'b1,
      write_lock: 1'b1,
      read_lock:  1'b0,
      integrity:  1'b1
    },
    // HW_CFG1
    '{
      variant:    Buffered,
      offset:     14'd1672,
      size:       16,
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b0,
      hw_digest:  1'b1,
      write_lock: 1'b1,
      read_lock:  1'b0,
      integrity:  1'b1
    },
    // SECRET0
    '{
      variant:    Buffered,
      offset:     14'd1688,
      size:       40,
      key_sel:    Secret0Key,
      secret:     1'b1,
      sw_digest:  1'b0,
      hw_digest:  1'b1,
      write_lock: 1'b1,
      read_lock:  1'b1,
      integrity:  1'b1
    },
    // SECRET1
    '{
      variant:    Buffered,
      offset:     14'd1728,
      size:       88,
      key_sel:    Secret1Key,
      secret:     1'b1,
      sw_digest:  1'b0,
      hw_digest:  1'b1,
      write_lock: 1'b1,
      read_lock:  1'b1,
      integrity:  1'b1
    },
    // SECRET2
    '{
      variant:    Buffered,
      offset:     14'd1816,
      size:       88,
      key_sel:    Secret2Key,
      secret:     1'b1,
      sw_digest:  1'b0,
      hw_digest:  1'b1,
      write_lock: 1'b1,
      read_lock:  1'b1,
      integrity:  1'b1
    },
    // LIFE_CYCLE
    '{
      variant:    LifeCycle,
      offset:     14'd1904,
      size:       88,
      key_sel:    key_sel_e'('0),
      secret:     1'b0,
      sw_digest:  1'b0,
      hw_digest:  1'b0,
      write_lock: 1'b0,
      read_lock:  1'b0,
      integrity:  1'b1
    }
  };

  typedef enum {
    VendorTestIdx,
    CreatorSwCfgIdx,
    OwnerSwCfgIdx,
    HwCfg0Idx,
    HwCfg1Idx,
    Secret0Idx,
    Secret1Idx,
    Secret2Idx,
    LifeCycleIdx,
    // These are not "real partitions", but in terms of implementation it is convenient to
    // add these at the end of certain arrays.
    DaiIdx,
    LciIdx,
    KdiIdx,
    // Number of agents is the last idx+1.
    NumAgentsIdx
  } part_idx_e;

  parameter int NumAgents = int'(NumAgentsIdx);

  // Breakout types for easier access of individual items.
  typedef struct packed {
    logic [63:0] hw_cfg0_digest;
    logic [255:0] manuf_state;
    logic [255:0] device_id;
  } otp_hw_cfg0_data_t;

  // default value used for intermodule
  parameter otp_hw_cfg0_data_t OTP_HW_CFG0_DATA_DEFAULT = '{
    hw_cfg0_digest: 64'hD2BF0E2CFC07120E,
    manuf_state: 256'h55BE0BF60F328302F6008FEDD015995F818E6D5088A5CDF93C0F42DCF28BBDCA,
    device_id: 256'h39D3131745015730931F5DA9AF1C3AACE93BC3CE277DADEF07D7A8934EE34FBD
  };
  typedef struct packed {
    logic [63:0] hw_cfg1_digest;
    logic [23:0] unallocated;
    prim_mubi_pkg::mubi8_t en_sram_ifetch;
    logic [31:0] soc_dbg_state;
  } otp_hw_cfg1_data_t;

  // default value used for intermodule
  parameter otp_hw_cfg1_data_t OTP_HW_CFG1_DATA_DEFAULT = '{
    hw_cfg1_digest: 64'hBFD510D7D174D3C2,
    unallocated: 24'h0,
    en_sram_ifetch: prim_mubi_pkg::mubi8_t'(8'h69),
    soc_dbg_state: 32'h0
  };
  typedef struct packed {
    // This reuses the same encoding as the life cycle signals for indicating valid status.
    lc_ctrl_pkg::lc_tx_t valid;
    otp_hw_cfg1_data_t hw_cfg1_data;
    otp_hw_cfg0_data_t hw_cfg0_data;
  } otp_broadcast_t;

  // default value for intermodule
  parameter otp_broadcast_t OTP_BROADCAST_DEFAULT = '{
    valid: lc_ctrl_pkg::Off,
    hw_cfg1_data: OTP_HW_CFG1_DATA_DEFAULT,
    hw_cfg0_data: OTP_HW_CFG0_DATA_DEFAULT
  };


  // OTP invalid partition default for buffered partitions.
  parameter logic [15935:0] PartInvDefault = 15936'({
    704'({
      320'hBCEE0EAF635CC94C13341B2009F127B06D6A802324A832B510525C360F4D65C7B4D832618CCF4986,
      384'h813C1F50880EDCF619237C65265AB0F0C7BE3EA7E34C01040DEFD9C319666A73808EC748F9D19EC735CF8C381C8C5AFE
    }),
    704'({
      64'hFA9CE9B9595C0B9D,
      256'h7FDBA3FABBB202307AE064132CE3E678577E62959EFB89B7A2059F462D20F72,
      256'h27D331CD45A0EF7756EC4F708F6120840D5F33333CE062950E21D4D55ADB2645,
      128'hC20EEF44B66C882A67F85AFE2A82CBE0
    }),
    704'({
      64'h9EBCF683C0FC7778,
      128'h5ACC5965CAAD333087782B16192CB31F,
      256'h8C2B4F3535255D0B9EE36806F4741D1FF361DABDEC71147847CFC21F565393A4,
      256'h88EFD6E008A8D1E756E1E07F5EBCD245FA43D4382195A330424EDF34DF61C686
    }),
    320'({
      64'hA8DEB8ABE2DA8416,
      128'h827AA3F6BBFB187728C1F8823EC901A4,
      128'hEA922083D08D74C031E0F4A706AC2F4C
    }),
    128'({
      64'hBFD510D7D174D3C2,
      24'h0, // unallocated space
      8'h69,
      32'h0
    }),
    576'({
      64'hD2BF0E2CFC07120E,
      256'h55BE0BF60F328302F6008FEDD015995F818E6D5088A5CDF93C0F42DCF28BBDCA,
      256'h39D3131745015730931F5DA9AF1C3AACE93BC3CE277DADEF07D7A8934EE34FBD
    }),
    6144'({
      64'hA8184B94FC7A6455,
      1856'h0, // unallocated space
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      512'h0,
      128'h0,
      128'h0,
      512'h0,
      2560'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    6144'({
      64'h74501C921B4BAE3A,
      3744'h0, // unallocated space
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      64'h0,
      32'h0,
      64'h0,
      32'h0,
      32'h0,
      32'h0,
      1248'h0
    }),
    512'({
      64'hE24632038254ADF2,
      448'h0
    })});

  ///////////////////////////////////////////////
  // Parameterized Assignment Helper Functions //
  ///////////////////////////////////////////////

  function automatic otp_ctrl_core_hw2reg_t named_reg_assign(
      logic [NumPart-1:0][ScrmblBlockWidth-1:0] part_digest);
    logic unused_digest;
    otp_ctrl_core_hw2reg_t hw2reg;
    hw2reg = '0;
    unused_digest = 1'b0;
    hw2reg.vendor_test_digest = part_digest[VendorTestIdx];
    hw2reg.creator_sw_cfg_digest = part_digest[CreatorSwCfgIdx];
    hw2reg.owner_sw_cfg_digest = part_digest[OwnerSwCfgIdx];
    hw2reg.hw_cfg0_digest = part_digest[HwCfg0Idx];
    hw2reg.hw_cfg1_digest = part_digest[HwCfg1Idx];
    hw2reg.secret0_digest = part_digest[Secret0Idx];
    hw2reg.secret1_digest = part_digest[Secret1Idx];
    hw2reg.secret2_digest = part_digest[Secret2Idx];
    unused_digest ^= ^part_digest[LifeCycleIdx];
    return hw2reg;
  endfunction : named_reg_assign

  function automatic part_access_t [NumPart-1:0] named_part_access_pre(
      otp_ctrl_core_reg2hw_t reg2hw);
    part_access_t [NumPart-1:0] part_access_pre;
    logic unused_sigs;
    unused_sigs = ^reg2hw;
    // Default (this will be overridden by partition-internal settings).
    part_access_pre = {{32'(2*NumPart)}{prim_mubi_pkg::MuBi8False}};
    // Note: these could be made a MuBi CSRs in the future.
    // The main thing that is missing right now is proper support for W0C.
    if (!reg2hw.vendor_test_read_lock) begin
      part_access_pre[VendorTestIdx].read_lock = prim_mubi_pkg::MuBi8True;
    end
    if (!reg2hw.creator_sw_cfg_read_lock) begin
      part_access_pre[CreatorSwCfgIdx].read_lock = prim_mubi_pkg::MuBi8True;
    end
    if (!reg2hw.owner_sw_cfg_read_lock) begin
      part_access_pre[OwnerSwCfgIdx].read_lock = prim_mubi_pkg::MuBi8True;
    end
    return part_access_pre;
  endfunction : named_part_access_pre

  function automatic otp_broadcast_t named_broadcast_assign(
      logic [NumPart-1:0] part_init_done,
      logic [$bits(PartInvDefault)/8-1:0][7:0] part_buf_data);
    otp_broadcast_t otp_broadcast;
    logic valid, unused;
    unused = 1'b0;
    valid = 1'b1;
    unused ^= ^{part_init_done[LifeCycleIdx],
                part_buf_data[LifeCycleOffset +: LifeCycleSize]};
    unused ^= ^{part_init_done[Secret2Idx],
                part_buf_data[Secret2Offset +: Secret2Size]};
    unused ^= ^{part_init_done[Secret1Idx],
                part_buf_data[Secret1Offset +: Secret1Size]};
    unused ^= ^{part_init_done[Secret0Idx],
                part_buf_data[Secret0Offset +: Secret0Size]};
    valid &= part_init_done[HwCfg1Idx];
    otp_broadcast.hw_cfg1_data = otp_hw_cfg1_data_t'(part_buf_data[HwCfg1Offset +: HwCfg1Size]);
    valid &= part_init_done[HwCfg0Idx];
    otp_broadcast.hw_cfg0_data = otp_hw_cfg0_data_t'(part_buf_data[HwCfg0Offset +: HwCfg0Size]);
    unused ^= ^{part_init_done[OwnerSwCfgIdx],
                part_buf_data[OwnerSwCfgOffset +: OwnerSwCfgSize]};
    unused ^= ^{part_init_done[CreatorSwCfgIdx],
                part_buf_data[CreatorSwCfgOffset +: CreatorSwCfgSize]};
    unused ^= ^{part_init_done[VendorTestIdx],
                part_buf_data[VendorTestOffset +: VendorTestSize]};
    otp_broadcast.valid = lc_ctrl_pkg::lc_tx_bool_to_lc_tx(valid);
    return otp_broadcast;
  endfunction : named_broadcast_assign


endpackage : otp_ctrl_part_pkg
