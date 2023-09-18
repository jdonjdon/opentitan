class usb20_agent extends dv_base_agent#(
  .CFG_T          (usb20_agent_cfg),
  .DRIVER_T       (usb20_driver),
  .SEQUENCER_T    (usb20_sequencer),
  .MONITOR_T      (usb20_monitor),
  .COV_T          (usb20_agent_cov)
);
