// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
typedef class flash_ctrl_scoreboard;

class flash_ctrl_env_cfg extends cip_base_env_cfg #(
  .RAL_T(flash_ctrl_core_reg_block)
);

  // Memory backdoor util instances for each partition in each bank.
  mem_bkdr_util mem_bkdr_util_h[flash_dv_part_e][flash_ctrl_pkg::NumBanks];

  // Pass scoreboard handle to address multiple exp_alert issue.
  flash_ctrl_scoreboard scb_h;

  // seq cfg
  flash_ctrl_seq_cfg seq_cfg;

  // Flash phy prim interface agent config
  flash_phy_prim_agent_cfg m_fpp_agent_cfg;
  // interface
  virtual flash_ctrl_if flash_ctrl_vif;
  virtual flash_ctrl_dv_if flash_ctrl_dv_vif;
  virtual clk_rst_if clk_rst_vif_flash_ctrl_eflash_reg_block;

  // knobs
  // ral.status[init_wip] status is set for the very first clock cycle right out of reset.
  // This causes problems in the read value especially in CSR tests.
  int post_reset_delay_clks = 1;

  // Knob for blocking host reads
  bit block_host_rd = 0;

  // Knob for control direct read checking
  bit dir_rd_in_progress = 1'b0;

  // Knob for scoreboard write and check on reads
  bit scb_check = 0;

  // Knob for scoreboard set expected alert
  bit scb_set_exp_alert = 0;

  // Knob for Bank Erase
  bit bank_erase_enable = 1;

  // Enable full checks of the scoreboard memory model, enabled by default.
  bit check_full_scb_mem_model = 1'b1;

  // mem for scoreboard
  data_model_t scb_flash_data = '{default: 1};
  data_model_t scb_flash_info = '{default: 1};
  data_model_t scb_flash_info1 = '{default: 1};
  data_model_t scb_flash_info2 = '{default: 1};

  // Knob to enable on the fly scoreboard.
  bit scb_otf_en = 0;

  // TB ecc support enable
  // With ecc enabled, read path requires pre encoded data patterns.
  // 0 : no ecc
  // 1 : ecc enable
  // 2 : 1 bit error test mode
  //     Based on serr_pct, single bit error is injected in 'flash_mem_otf_read'
  // 3 : 2 bit error test mode
  // 4 : integrity error test mode
  ecc_mode_e ecc_mode = FlashEccDisabled;

  // single bit error rate scale of 0~10. 10: 100%.
  int serr_pct = 0;
  // Store single bit errored line to hash.
  // If address exists, skip extra error injection to avoid
  // creating multi bit errors
  bit serr_addr_tbl[addr_t];
  int serr_cnt[NumBanks] = '{default : 0};
  // latest single bit error address
  bit [OTFBankId:0] serr_addr[NumBanks];

  // Create serr only once. Used in directed test case.
  bit serr_once = 0;
  bit serr_created = 0;

  // Double bit error test
  int derr_pct = 0;
  int derr_idx[76];
  bit derr_addr_tbl[addr_t];
  bit derr_once = 0;
  bit derr_created[2] = '{default : 0};

  // Mark out standing transactions.
  // With heavy concurrency, derr can be injected where read transaction
  // is issued and outstanding.
  // This can change error expectation of the first transaction.
  // To handle this conrnercase, don't assert derr on outstanding read location.
  int derr_otd[addr_t];

  // Integrity ecc err
  int ierr_pct = 0;
  bit ierr_addr_tbl[addr_t];
  bit ierr_created[2] = '{default : 0};
  // Transaction counters for otf
  int otf_ctrl_wr_sent = 0;
  int otf_ctrl_wr_rcvd = 0;
  int otf_ctrl_rd_sent = 0;
  int otf_ctrl_rd_rcvd = 0;
  int otf_host_rd_sent = 0;
  int otf_host_rd_rcvd = 0;

  // Page to region map.
  // This is used to validate transactions based on their page address
  // and policy config associate with it.
  // 8 : default region
  int p2r_map[FlashNumPages] = '{default : 8};

  flash_mp_region_cfg_t mp_regions[MpRegions];
  flash_bank_mp_info_page_cfg_t mp_info[NumBanks][InfoTypes][];

  // Permission to access special partition
  // 0: secret / creator
  // 1: secret / owner
  // 2: isolated
  bit [2:0] allow_spec_info_acc = 3'h0;

  // Allow multiple expected allert in a single test
  bit multi_alert_en = 0;

  // Max delay for alerts in clocks
  uint alert_max_delay;

  // Max delay for alerts in ns
  int alert_max_delay_in_ns;

  // read data by host if
  data_q_t flash_rd_data;

  // 2bit of target prefix. Use with cfg.ecc_mode > FlashEccDisabled
  // When cfg.ecc_mode > FlashEccDisabled, this will be randomized
  // before sequence starts.
  // tgt_pre[0]: rd
  // tgt_pre[1]: direct_rd
  // tgt_pre[2]: wr
  // tgt_pre[3]: rsvd
  // then assigned to bit 18:17
  bit [1:0] tgt_pre[flash_dv_part_e][NumTgt];


  `uvm_object_utils(flash_ctrl_env_cfg)

  `uvm_object_new

  string flash_ral_name = "flash_ctrl_eflash_reg_block";

  virtual function void initialize(addr_t csr_base_addr = '1);
    list_of_alerts = flash_ctrl_env_pkg::LIST_OF_ALERTS;
    has_shadowed_regs = 1;
    tl_intg_alert_name = "fatal_std_err";

    // Set up second RAL model for Flash memory
    ral_model_names.push_back(flash_ral_name);

    // both RAL models use same clock frequency
    clk_freqs_mhz[flash_ral_name] = clk_freq_mhz;

    super.initialize(csr_base_addr);

    tl_intg_alert_fields[ral.std_fault_status.reg_intg_err] = 1;
    shadow_update_err_status_fields[ral.err_code.update_err] = 1;
    shadow_storage_err_status_fields[ral.std_fault_status.storage_err] = 1;

    // create the seq_cfg and call configure
    seq_cfg = flash_ctrl_seq_cfg::type_id::create("seq_cfg");
    seq_cfg.configure();

    m_fpp_agent_cfg = flash_phy_prim_agent_cfg::type_id::create("m_fpp_agent_cfg");
    m_fpp_agent_cfg.is_active = 0;
    m_fpp_agent_cfg.en_cov = 0;

    // set num_interrupts & num_alerts
    begin
      uvm_reg rg = ral.get_reg_by_name("intr_state");
      if (rg != null) begin
        num_interrupts = ral.intr_state.get_n_used_bits();
      end
    end
    alert_max_delay = 20000;
    `uvm_info(`gfn, $sformatf("ral_model_names: %0p", ral_model_names), UVM_LOW)

    foreach (tgt_pre[FlashPartData][i]) tgt_pre[FlashPartData][i] = i;
    foreach (tgt_pre[FlashPartInfo][i]) tgt_pre[FlashPartInfo][i] = i;
    foreach (tgt_pre[FlashPartInfo1][i]) tgt_pre[FlashPartInfo1][i] = i;
    foreach (tgt_pre[FlashPartInfo2][i]) tgt_pre[FlashPartInfo2][i] = i;

    foreach (derr_idx[i]) derr_idx[i] = i;
    foreach (mp_info[i, j]) mp_info[i][j] = new[InfoTypeSize[j]];

  endfunction : initialize

  // For a given partition returns its size in bytes in each of the banks.
  function uint get_partition_words_num(flash_dv_part_e part);
    case(part)
      FlashPartData:    return BytesPerBank / 4;
      FlashPartInfo:    return InfoTypeBytes[0] / 4;
      FlashPartInfo1:   return InfoTypeBytes[1] / 4;
      FlashPartInfo2:   return InfoTypeBytes[2] / 4;
      default: `uvm_error(`gfn, $sformatf("Undefined partition - %s", part.name()))
    endcase
  endfunction : get_partition_words_num

  // Method to do a back-door update of a selected partition memory model to the actual flash data.
  // Usualy should only be done after flash initialization.
  task update_partition_mem_model(flash_dv_part_e part);
    flash_mem_addr_attrs addr_attr;
    data_4s_t bkdr_rd_data;
    uint partition_words_num;
    data_model_t scb_flash_model;
    addr_attr = new();
    partition_words_num = get_partition_words_num(part);

    `uvm_info(`gfn, $sformatf("\nStart back-door updating partition %s memory model\n",
                              part.name()), UVM_MEDIUM)

    for (int i = 0; i < flash_ctrl_pkg::NumBanks; i++) begin : iterate_all_banks
      addr_attr.set_attrs(i * BytesPerBank);
      for (int j = 0; j < partition_words_num; j++) begin : iterate_all_bank_partition_words
        bkdr_rd_data = mem_bkdr_util_h[part][addr_attr.bank].read32(addr_attr.bank_addr);
        if ($isunknown(bkdr_rd_data)) begin
          scb_flash_model[addr_attr.addr] = ALL_ONES;
        end else begin
          scb_flash_model[addr_attr.addr] = bkdr_rd_data;
        end
        addr_attr.incr(flash_ctrl_pkg::BusBytes);
      end : iterate_all_bank_partition_words
    end : iterate_all_banks

    case(part)
      flash_ctrl_env_pkg::FlashPartData:    scb_flash_data      = scb_flash_model;
      flash_ctrl_env_pkg::FlashPartInfo:    scb_flash_info      = scb_flash_model;
      flash_ctrl_env_pkg::FlashPartInfo1:   scb_flash_info1     = scb_flash_model;
      flash_ctrl_env_pkg::FlashPartInfo2:   scb_flash_info2     = scb_flash_model;
      default: `uvm_error(`gfn, $sformatf("Undefined partition - %s", part.name()))
    endcase

    `uvm_info(`gfn, $sformatf("\nFinished back-door updating partition %s memory model\n",
                              part.name()), UVM_MEDIUM)

  endtask : update_partition_mem_model

  // Backdoor initialize flash memory elements.
  // Applies the initialization scheme to the given flash partition in all banks.
  // @part is the type of flash partition.
  // @scheme is the type of initialization to be done.
  virtual task flash_mem_bkdr_init(flash_dv_part_e part = FlashPartData,
                                   flash_mem_init_e scheme);

    `uvm_info("flash_mem_bkdr_init", $sformatf("scheme: %s", scheme.name), UVM_MEDIUM)
    case (scheme)
      FlashMemInitSet: begin
        foreach (mem_bkdr_util_h[part][i]) mem_bkdr_util_h[part][i].set_mem();
      end
      FlashMemInitClear: begin
        foreach (mem_bkdr_util_h[part][i]) mem_bkdr_util_h[part][i].clear_mem();
      end
      FlashMemInitRandomize: begin
        foreach (mem_bkdr_util_h[part][i]) mem_bkdr_util_h[part][i].randomize_mem();
      end
      FlashMemInitInvalidate: begin
        foreach (mem_bkdr_util_h[part][i]) mem_bkdr_util_h[part][i].invalidate_mem();
      end
      FlashMemInitEccMode: begin
        foreach (mem_bkdr_util_h[part][i]) mem_bkdr_util_h[part][i].set_mem();
      end
      default: begin
        `uvm_error(`gfn, $sformatf("Undefined initialization scheme - %s", scheme.name()))
      end
    endcase
    // Update the memory model with the initialization data
    if (scb_check) update_partition_mem_model(part);
  endtask : flash_mem_bkdr_init

  // For a given partition returns its respective memory model.
  function data_model_t get_partition_mem_model(flash_ctrl_env_pkg::flash_dv_part_e part);
    case(part)
      flash_ctrl_env_pkg::FlashPartData:    return scb_flash_data;
      flash_ctrl_env_pkg::FlashPartInfo:    return scb_flash_info;
      flash_ctrl_env_pkg::FlashPartInfo1:   return scb_flash_info1;
      flash_ctrl_env_pkg::FlashPartInfo2:   return scb_flash_info2;
      default: `uvm_error(`gfn, $sformatf("Undefined partition - %s", part.name()))
    endcase
  endfunction : get_partition_mem_model

  // Task to back-door check a selected partition memory model
  // This will be called in the scoreboard check_phase if the check_full_scb_mem_model will
  //  be set to 1 (enabled by default).
  function void check_partition_mem_model(flash_ctrl_env_pkg::flash_dv_part_e part);
    flash_mem_addr_attrs addr_attr;
    data_4s_t bkdr_rd_data;
    data_model_t scb_flash_model = get_partition_mem_model(part);
    addr_attr = new();
    foreach (scb_flash_model[addr]) begin
      addr_attr.set_attrs(addr);
      bkdr_rd_data = mem_bkdr_util_h[part][addr_attr.bank].read32(addr_attr.bank_addr);
      if ($isunknown(bkdr_rd_data)) bkdr_rd_data = ALL_ONES;
      `DV_CHECK_EQ(bkdr_rd_data, scb_flash_model[addr],
                   $sformatf({"Memory model check failed in partition %s, bank %0d, addr 0x%0x ",
                              "(%0d)"}, part.name(), addr_attr.bank, addr_attr.bank_addr,
                              addr_attr.bank_addr))
    end
  endfunction : check_partition_mem_model

  // Task to back-door check the full memory model
  // This will be called in the scoreboard check_phase & between calls to the inner rand_ops vseq
  //  (in partner_flash_ctrl_base_vseq post_tran task) if the check_full_scb_mem_model will
  //  be set to 1 (enabled by default).
  function void check_mem_model();
    flash_ctrl_env_pkg::flash_dv_part_e part = part.first();
    `uvm_info(`gfn, $sformatf("\nStart checking all memory model\n"), UVM_MEDIUM)
    do begin
      check_partition_mem_model(part);
      part = part.next();
    end while (part != part.first());
    `uvm_info(`gfn, $sformatf("\nFinished checking all memory model\n"), UVM_MEDIUM)
  endfunction : check_mem_model

  // Read full word from the memory. (76bits per word line)
  // flash_op.op should be FlashOpRead
  function void flash_mem_otf_read(flash_op_t flash_op, ref fdata_q_t data);
    flash_dv_part_e partition;
    int bank;
    bit [75:0] rdata;
    int        size, is_odd, tail;
    addr_t aligned_addr;

    aligned_addr = flash_op.addr;
    // QW (8byte) align
    aligned_addr[2:0] = 'h0;
    bank = flash_op.addr[OTFBankId];
    partition = flash_op.partition;
    // If address is not 8byte aligned, full 76bit has to be read.
    // This exception is identified using 4Byte address bit, (addr[2])
    // and size of 4byte word.
    is_odd = flash_op.addr[2];
    size = (flash_op.num_words + is_odd) / 2;
    tail = (flash_op.num_words + is_odd) % 2;

    `uvm_info("flash_mem_otf_read", $sformatf("is_odd:%0d size:%0d tail:%0d wd:%0d",
                                            is_odd, size, tail, flash_op.num_words), UVM_MEDIUM)
    // Use per bank address.
    aligned_addr[31:OTFBankId] = 'h0;
    for (int i = 0; i < size; i++) begin
      rdata = mem_bkdr_util_h[partition][bank].read(aligned_addr);
      data.push_back(rdata);
      aligned_addr += 8;
    end
    if (tail) begin
      rdata = mem_bkdr_util_h[partition][bank].read(aligned_addr);
      data.push_back(rdata);
    end
  endfunction // flash_mem_otf_read

  // Reads flash mem contents via backdoor.
  //
  // The addr arg need not be word aligned - its the same addr programmed into the `control` CSR.
  // TODO: add support for partition.
  virtual function void flash_mem_bkdr_read(flash_op_t flash_op, ref data_q_t data);
    flash_mem_addr_attrs             addr_attrs = new(flash_op.addr);

    if (flash_op.op == flash_ctrl_pkg::FlashOpErase) begin
      case (flash_op.erase_type)
        flash_ctrl_pkg::FlashErasePage: begin
          addr_attrs.set_attrs(addr_attrs.bank_start_addr + addr_attrs.page_start_addr);
          flash_op.num_words = FlashNumBusWordsPerPage;
        end
        flash_ctrl_pkg::FlashEraseBank: begin
          addr_attrs.set_attrs(addr_attrs.bank * BytesPerBank);
          case (flash_op.partition)
            FlashPartData: begin
              flash_op.num_words = FlashNumBusWordsPerBank;
            end
            FlashPartInfo: begin
              flash_op.num_words = InfoTypeBusWords[0];
            end
            default: begin
              `uvm_fatal(`gfn, $sformatf(
                         {
                           "Invalid partition for bank_erase: %0s. ",
                           "Bank erase is only valid in the data partition ",
                           "(FlashPartData) and the first info partition ",
                           "(FlashPartInfo)."
                         },
                         flash_op.partition.name()
                         ))
            end
          endcase
        end
        default: begin
          `uvm_fatal(`gfn, $sformatf("Invalid erase_type: %0s", flash_op.erase_type.name()))
        end
      endcase
    end

    data.delete();
    for (int i = 0; i < flash_op.num_words; i++) begin
      data[i] = mem_bkdr_util_h[flash_op.partition][addr_attrs.bank].read32(addr_attrs.bank_addr);
      `uvm_info(`gfn, $sformatf(
                                "flash_mem_bkdr_read: partition = %s , {%s} = 0x%0h",
                                flash_op.partition.name(),
                                addr_attrs.sprint(),
                                data[i]
                                ), UVM_HIGH)
      addr_attrs.incr(TL_DBW);
    end
  endfunction : flash_mem_bkdr_read

  // Writes the flash mem contents via backdoor.
  //
  // The addr need not be bus word aligned, Its the same addr programmed into the `control` CSR.
  // The data queue is sized for the bus word.
  // TODO: support for partition.
  virtual function void flash_mem_bkdr_write(flash_op_t flash_op, flash_mem_init_e scheme,
                                             data_q_t data = {});
    flash_mem_addr_attrs addr_attrs = new(flash_op.addr);
    data_4s_t wr_data;
    data_b_t mem_data;

    // Randomize the lower half-word (if Xs) if the first half-word written in the below loop is
    // corresponding upper half-word.
    if (addr_attrs.bank_addr[flash_ctrl_pkg::DataByteWidth-1]) begin
      _randomize_uninitialized_half_word(.partition(flash_op.partition), .bank(addr_attrs.bank),
                                         .addr(addr_attrs.word_addr));
    end

    case (scheme)
      FlashMemInitCustom: begin
        flash_op.num_words = data.size();
      end
      FlashMemInitSet: begin
        wr_data = {flash_ctrl_pkg::DataWidth{1'b1}};
      end
      FlashMemInitClear: begin
        wr_data = {flash_ctrl_pkg::DataWidth{1'b0}};
      end
      FlashMemInitInvalidate: begin
        wr_data = {flash_ctrl_pkg::DataWidth{1'bx}};
      end
    endcase

    for (int i = 0; i < flash_op.num_words; i++) begin
      data_4s_t loc_data = (scheme == FlashMemInitCustom) ? data[i] :
                 (scheme == FlashMemInitRandomize) ? $urandom() : wr_data;

      _flash_full_write(flash_op.partition, addr_attrs.bank, addr_attrs.bank_addr, loc_data);
      `uvm_info(`gfn, $sformatf(
                                "flash_mem_bkdr_write: partition = %s, {%s} = 0x%0h",
                                flash_op.partition.name(),
                                addr_attrs.sprint(),
                                loc_data
                                ), UVM_HIGH)

      // update the scoreboard on backdoor-programs as well
      mem_data[0] = loc_data;
      set_scb_mem(1, flash_op.partition,
                  addr_attrs.addr, CustomVal, mem_data);

      // increment after all updates are complete
      addr_attrs.incr(TL_DBW);
    end

    // Randomize the upper half-word (if Xs) if the last word written in the above loop is
    // corresponding lower half-word.
    if (addr_attrs.bank_addr[flash_ctrl_pkg::DataByteWidth-1]) begin
      _randomize_uninitialized_half_word(.partition(flash_op.partition), .bank(addr_attrs.bank),
                                         .addr(addr_attrs.bank_addr));
    end
  endfunction : flash_mem_bkdr_write

  // Helper function that takes a 32-bit data and correctly populates the integrity ECC
  //
  function void _flash_full_write(flash_dv_part_e partition, uint bank,
                                  // bus word aligned address
                                  addr_t addr,
                                  data_t wr_data);

    // read back the full flash word
    logic [flash_ctrl_pkg::DataWidth-1:0] data;
    logic [7:0] intg_data;
    logic is_upper = addr[flash_ctrl_pkg::DataByteWidth-1];
    addr_t aligned_addr = addr;

    if (is_upper) begin
      aligned_addr = {addr[TL_AW-1:FlashDataByteWidth], {FlashDataByteWidth{1'b0}}};
    end

    // get the full flash word
    data = mem_bkdr_util_h[partition][bank].read64(aligned_addr);

    // writing the upper portion of the flash word
    if (is_upper) begin
      data = {wr_data, data[TL_DW-1:0]};
    end else begin
      data = {data[flash_ctrl_pkg::DataWidth-:TL_DW], wr_data};
    end

    // calculate truncated integrity
    {intg_data, data} = prim_secded_pkg::prim_secded_hamming_72_64_enc(data);

    // program fully via backdoor
    // TODO: review this later.
    // it has to be write(aligned_addr, instead of write64(aligned_addr
    mem_bkdr_util_h[partition][bank].write64(aligned_addr, {intg_data[3:0], data});

    // Update scoreboard memory model with this back-door write
    if (scb_check) begin
      write_data_all_part(.part(partition), .addr({bank, addr[FlashMemAddrPageMsbBit:0]}),
                          .is_front_door(1'b0), .data(wr_data));
    end

  endfunction : _flash_full_write


  // Helper function that randomizes the half-word at the given address if unknown.
  //
  // When the 'other' flash half-word is being written by the flash_mem_bkdr_write() method, the
  // half-word at the given address needs to also be updated, of the data at that address is
  // unknown. This is needed because the flash_ctrl RTL internally fetches full words. This method
  // randomizes the data at the given address via backdoor.
  function void _randomize_uninitialized_half_word(flash_dv_part_e partition, uint bank,
                                                   addr_t addr);
    data_4s_t data = mem_bkdr_util_h[partition][bank].read32(addr);
    if ($isunknown(data)) begin
      `DV_CHECK_STD_RANDOMIZE_FATAL(data)
      `uvm_info(`gfn, $sformatf("Data at 0x%0h is Xs, writing random 0x%0h", addr, data), UVM_HIGH)
      _flash_full_write(partition, bank, addr, data);
    end
  endfunction

  // Checks flash mem contents via backdoor.
  //
  // The addr need not be bus word aligned. Its the same addr programmed into the `control` CSR.
  // The exp data queue is sized for the bus word.
  // TODO: support for partition.
  virtual function void flash_mem_bkdr_read_check(flash_op_t flash_op, const ref data_q_t exp_data);
    data_q_t data;
    flash_mem_bkdr_read(flash_op, data);
    foreach (data[i]) begin
      `DV_CHECK_CASE_EQ(data[i], exp_data[i])
    end
  endfunction : flash_mem_bkdr_read_check

  // Verifies that the flash page / bank has indeed been erased.
  virtual function void flash_mem_bkdr_erase_check(flash_op_t flash_op, data_q_t exp_data = {});
    flash_mem_addr_attrs             addr_attrs = new(flash_op.addr);
    bit                  [TL_AW-1:0] erase_check_addr;
    string                           erase_page_num_msg;
    uint                             num_words;

    case (flash_op.erase_type)
      flash_ctrl_pkg::FlashErasePage: begin
        erase_check_addr = addr_attrs.page_start_addr;
        num_words = FlashNumBusWordsPerPage;
        erase_page_num_msg = $sformatf("page = %0d, ", addr_attrs.page);
      end
      flash_ctrl_pkg::FlashEraseBank: begin
        // This address is relative to the bank it's in.
        erase_check_addr   = 0;
        // No need to state page for bank erase.
        erase_page_num_msg = "";
        case (flash_op.partition)
          FlashPartData: begin
            num_words = FlashNumBusWordsPerBank;
          end
          FlashPartInfo: begin
            num_words = InfoTypeBusWords[0];
          end
          default: begin
            `uvm_fatal(`gfn, $sformatf(
                       {
                         "Invalid partition for bank_erase: %0s. ",
                         "Bank erase is only valid in the data partition ",
                         "(FlashPartData) and the first info partition ",
                         "(FlashPartInfo)."
                       },
                       flash_op.partition.name()
                       ))
          end
        endcase
      end
      default: begin
        `uvm_fatal(`gfn, $sformatf("Invalid erase_type: %0s", flash_op.erase_type.name()))
      end
    endcase
    `uvm_info(`gfn, $sformatf(
              {
                "flash_mem_bkdr_erase_check: Erase type = %s, bank = %0d, ",
                "partition = %s , %snum_words = %0d"
              },
              flash_op.erase_type.name(),
              addr_attrs.bank,
              flash_op.partition.name(),
              erase_page_num_msg,
              num_words
              ), UVM_MEDIUM)

    for (int i = 0; i < num_words; i++) begin
      data_4s_t data;
      data = mem_bkdr_util_h[flash_op.partition][addr_attrs.bank].read32(erase_check_addr);
      `uvm_info(`gfn, $sformatf(
                {
                  "flash_mem_bkdr_erase_check: Erase type = %s, bank: %0d, ",
                  "partition: %s , %saddr: 0x%0h, data: 0x%0h"
                },
                flash_op.erase_type.name(),
                addr_attrs.bank,
                flash_op.partition.name(),
                erase_page_num_msg,
                erase_check_addr,
                data
                ), UVM_HIGH)
      // If the expected data is not empty then it should be taken is expected. If it is empty the
      //  default expected value is checked - which for successful erase is all 1s.
      if (exp_data.size() <= i) begin
        `DV_CHECK_CASE_EQ(data, '1)
      end else begin
        `DV_CHECK_CASE_EQ(data, exp_data[i])
      end
      erase_check_addr += TL_DBW;
    end
  endfunction : flash_mem_bkdr_erase_check

  // Function to enable changing of the expected data to be checked in the post-transaction
  // checks.
  virtual function data_q_t calculate_expected_data(flash_op_t flash_op,
                                                    const ref data_q_t exp_data);
    return exp_data;
  endfunction : calculate_expected_data

  // Writing data to the scoreboard memory model, this writes one word of data to the selected
  //  address in the selected partition.
  // is_front_door added to indicate if this method called by front-door
  //  write (program transaction), which is the default, or by back-door methods.
  //  This is required for extending env.
  virtual function void write_data_all_part(flash_dv_part_e part, addr_t addr,
                                            bit is_front_door = 1'b1, ref data_t data);
  `uvm_info(`gfn, $sformatf("WRITE SCB MEM part: %0s addr:%0h data:0x%0h",
                            part.name, addr, data), UVM_HIGH)
    case (part)
      FlashPartData: scb_flash_data[addr] = data;
      FlashPartInfo: scb_flash_info[addr] = data;
      FlashPartInfo1: scb_flash_info1[addr] = data;
      FlashPartInfo2: scb_flash_info2[addr] = data;
      default: `uvm_fatal(`gfn, "flash_ctrl_scoreboard: Partition type not supported!")
    endcase
  endfunction

  // Task for clean scb memory
  virtual function reset_scb_mem();
    scb_flash_data.delete();
    scb_flash_info.delete();
    scb_flash_info1.delete();
    scb_flash_info2.delete();
  endfunction : reset_scb_mem

  // Task for set scb memory
  virtual function set_scb_mem(int bkd_num_words, flash_dv_part_e bkd_partition,
                               addr_t write_bkd_addr,flash_scb_wr_e val_type,
                               data_b_t custom_val = {});
    addr_t wr_bkd_addr;
    data_t wr_value;

    `uvm_info(`gfn, $sformatf(
              "SET SCB MEM TEST part: %0s addr:%0h data:0x%0h num: %0d",
              bkd_partition.name,
              write_bkd_addr,
              wr_value,
              bkd_num_words
              ), UVM_HIGH)
    wr_bkd_addr = {write_bkd_addr[TL_AW-1:2], 2'b00};
    `uvm_info(`gfn, $sformatf("SET SCB MEM ADDR:%0h", wr_bkd_addr), UVM_HIGH)
    for (int i = 0; i < bkd_num_words; i++) begin
      case (val_type)
        AllOnes: begin
          wr_value = ALL_ONES;
        end
        AllZeros: begin
          wr_value = ALL_ZEROS;
        end
        CustomVal: begin
          wr_value = custom_val[i];
        end
        default: `uvm_fatal(`gfn, "Unknown write type, allowed: AllOnes, AllZeros, CustomVal")
      endcase
      `uvm_info(`gfn, $sformatf(
                "SET SCB MEM part: %0s addr:%0h data:0x%0h num: %0d",
                bkd_partition.name,
                wr_bkd_addr,
                wr_value,
                bkd_num_words
                ), UVM_HIGH)
      write_data_all_part(.part(bkd_partition), .addr(wr_bkd_addr), .is_front_door(1'b0),
                          .data(wr_value));
      wr_bkd_addr = wr_bkd_addr + 4;
    end
  endfunction : set_scb_mem

  function int get_serr_idx();
    int rnd_odds;
    int idx = -1;
    if (serr_once == 1 && serr_created == 1) return -1;
    if (ecc_mode == FlashSerrTestMode) begin
      rnd_odds = $urandom_range(0,9);
      if (rnd_odds < serr_pct) begin
        idx = $urandom_range(0, 75);
        serr_created = 1;
      end
    end

    return idx;
  endfunction // get_err_idx

  // Increase single bit error count.
  function void inc_serr_cnt(int bank, bit dis = 0);
    if (serr_cnt[bank] < 255) serr_cnt[bank]++;
    if (dis) begin
      `uvm_info("inc_serr_cnt", $sformatf("serr_cnt[%0d]=%0d", bank, serr_cnt[bank]), UVM_MEDIUM)
    end
  endfunction

  // Flip a bit at given address.
  function void flash_bit_flip(mem_bkdr_util _h, addr_t addr, int idx);
    bit [75:0] rdata;
    rdata = _h.read(addr);
    rdata[idx] = ~rdata[idx];
    _h.write(addr, rdata);
  endfunction

  // Corrupt integrity check value only
  function void flash_icv_flip(mem_bkdr_util _h, addr_t addr,
                               flash_otf_item exp_item);
    flash_otf_item item;

    `uvm_create_obj(flash_otf_item, item)
    item.dq.push_back($urandom());
    item.dq.push_back($urandom());
    item.region = exp_item.region;
    item.scramble(exp_item.addr_key, exp_item.data_key, addr, 0, 1);
    _h.write(addr, item.fq[0]);
    item.clear_qs();
  endfunction

  // Create bit error follwing flash_op and  ecc_mode.
  // @caller : 0 controller,  1: host
  function void add_bit_err(flash_op_t flash_op, read_task_e caller = ReadTaskCtrl,
                            flash_otf_item item = null);
    flash_dv_part_e partition;
    int bank;
    bit [75:0] rdata;
    int        size, is_odd, tail;
    int        err_idx;
    addr_t aligned_addr, addr_cp;
    string     name = $sformatf("add_bit_err from %s", caller.name);

    err_idx = -1;
    aligned_addr = flash_op.addr;
    // QW (8byte) align
    aligned_addr[2:0] = 'h0;
    bank = flash_op.addr[OTFBankId];
    partition = flash_op.partition;
    // If address is not 8byte aligned, full 76bit has to be read.
    // This exception is identified using 4Byte address bit, (addr[2])
    // and size of 4byte word.
    is_odd = flash_op.addr[2];
    size = (flash_op.num_words + is_odd) / 2;
    tail = (flash_op.num_words + is_odd) % 2;

    addr_cp = aligned_addr;
    if (ecc_mode == FlashDerrTestMode && derr_otd.exists(addr_cp)) return;
    // Use per bank address.
    aligned_addr[31:OTFBankId] = 'h0;
    for (int i = 0; i < size; i++) begin
      if (ecc_mode == FlashSerrTestMode) begin
        err_idx = get_serr_idx();
        if (err_idx >= 0) begin
          // Make sure only assert error only once per address
          if (!serr_addr_tbl.exists(addr_cp)) begin
            serr_addr_tbl[addr_cp] = 1;
            `uvm_info(name,
                      $sformatf("single bit error is inserted at line:%0d the databit[%0d]",
                                i, err_idx), UVM_MEDIUM)
            flash_bit_flip(mem_bkdr_util_h[partition][bank], aligned_addr, err_idx);
          end
        end
      end else if (ecc_mode == FlashIerrTestMode) begin
        randcase
          ierr_pct: begin
            if (!ierr_addr_tbl.exists(addr_cp)) begin
              ierr_addr_tbl[addr_cp] = 1;
              `uvm_info(name,
                        $sformatf("icv error is inserted at line:%0d", i), UVM_MEDIUM)
              flash_icv_flip(mem_bkdr_util_h[partition][bank], aligned_addr, item);
            end
            ierr_created[caller] = 1;
          end
          10-ierr_pct: begin
          end
        endcase // randcase
      end else begin // if (ecc_mode == FlashIerrTestMode)
        derr_idx.shuffle();
        err_idx = 0;
        if (derr_once == 0 || (derr_created[0] | derr_created[1]) == 0 ) begin
          repeat (2) begin
            randcase
              derr_pct: begin
                `uvm_info(name,
                          $sformatf({"addr:0x%x %x bit error is inserted at line:%0d",
                                     " the databit[%0d] err_idx:%0d"},
                                    aligned_addr, addr_cp, i, derr_idx[err_idx], err_idx),
                          UVM_MEDIUM)

                // If address already had a single bit error, just skip this line.
                // We could add another bit error then we have to model read cache behavior.
                if (err_idx != 0 || serr_addr_tbl.exists(addr_cp) == 0) begin
                  flash_bit_flip(mem_bkdr_util_h[partition][bank], aligned_addr,
                                 derr_idx[err_idx++]);
                  serr_addr_tbl[addr_cp] = 1;
                end
                if (err_idx == 2) begin
                  `uvm_info(name, $sformatf(" addr:0x%x is added to derr_addr_tbl", addr_cp),
                            UVM_MEDIUM)
                  derr_addr_tbl[addr_cp] = 1;
                  derr_created[caller] = 1;
                end
              end
              10-derr_pct: begin
              end
            endcase // randcase
          end
        end // if (derr_once == 0 || (|derr_created) == 0)
      end // else: !if(ecc_mode == FlashIerrTestMode)
      aligned_addr += 8;
      addr_cp[OTFBankId-1:0] = aligned_addr[OTFBankId-1:0];
    end
    if (tail) begin
      if (ecc_mode == FlashSerrTestMode) begin
        err_idx = get_serr_idx();
        if (err_idx >= 0) begin
          if (!serr_addr_tbl.exists(addr_cp)) begin
            serr_addr_tbl[addr_cp] = 1;
            `uvm_info(name,
                      $sformatf("single bit error is inserted at line:%0d the databit[%0d]",
                                size, err_idx), UVM_MEDIUM)
            flash_bit_flip(mem_bkdr_util_h[partition][bank], aligned_addr, err_idx);
          end
        end
      end else if (ecc_mode == FlashIerrTestMode) begin
        randcase
          ierr_pct: begin
            if (!ierr_addr_tbl.exists(addr_cp)) begin
              ierr_addr_tbl[addr_cp] = 1;
              `uvm_info(name,
                        $sformatf("last:icv error is inserted at line:%0d", size), UVM_MEDIUM)
              flash_icv_flip(mem_bkdr_util_h[partition][bank], aligned_addr, item);
            end
            ierr_created[caller] = 1;
          end
          10-ierr_pct: begin
          end
        endcase // randcase
      end else begin // if (ecc_mode == FlashIerrTestMode)
        derr_idx.shuffle();
        err_idx = 0;
        if (derr_once == 0 || (derr_created[0] | derr_created[1]) == 0) begin
          repeat (2) begin
            randcase
              derr_pct: begin
                `uvm_info(name,
                          $sformatf({"last:addr:0x%x %x bit error is inserted at line:%0d",
                                     " the databit[%0d] err_idx:%0d"},
                                    aligned_addr, addr_cp, size, derr_idx[err_idx], err_idx),
                          UVM_MEDIUM)
                if (err_idx != 0 || serr_addr_tbl.exists(addr_cp) == 0) begin
                  flash_bit_flip(mem_bkdr_util_h[partition][bank], aligned_addr,
                                 derr_idx[err_idx++]);
                  serr_addr_tbl[addr_cp] = 1;
                end
                if (err_idx == 2) begin
                  derr_addr_tbl[addr_cp] = 1;
                  derr_created[caller] = 1;
                end
              end
              10-derr_pct: begin
              end
            endcase // randcase
          end
        end // if (derr_once == 0 || (|derr_created) == 0)
      end // else: !if(ecc_mode == FlashIerrTestMode)
    end
  endfunction // add_bit_err

  // Increase outstanding table entry.
  function void inc_otd_tbl(addr_t addr);
    addr[2:0] = 3'h0;
    if (!derr_otd.exists(addr)) begin
      derr_otd[addr] = 1;
    end else begin
      derr_otd[addr]++;
    end
  endfunction // inc_otd_tbl
  // Descrease outstanding table entry.
  function void dec_otd_tbl(addr_t addr);
    addr[2:0] = 3'h0;
    if (!derr_otd.exists(addr)) begin
      `uvm_error("dec_otd_tbl", $sformatf("addr %x doesn't exits", addr))
    end else begin
      derr_otd[addr]--;
      if (derr_otd[addr] == 0) derr_otd.delete(addr);
    end
  endfunction // dec_otd_tbl

endclass
