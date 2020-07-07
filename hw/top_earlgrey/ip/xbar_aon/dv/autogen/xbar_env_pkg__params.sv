// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// xbar_env_pkg__params generated by `tlgen.py` tool


// List of Xbar device memory map
tl_device_t xbar_devices[$] = '{
    '{"pwrmgr_aon", '{
        '{32'h40400000, 32'h40400fff}
    }},
    '{"rstmgr_aon", '{
        '{32'h40410000, 32'h40410fff}
    }},
    '{"clkmgr_aon", '{
        '{32'h40420000, 32'h40420fff}
    }},
    '{"rbox_aon", '{
        '{32'h40430000, 32'h40430fff}
    }},
    '{"pinmux_aon", '{
        '{32'h40460000, 32'h40460fff}
    }},
    '{"padctrl_aon", '{
        '{32'h40470000, 32'h40470fff}
    }},
    '{"timer_aon", '{
        '{32'h40480000, 32'h40480fff}
    }},
    '{"usbdev_aon", '{
        '{32'h40500000, 32'h40500fff}
    }},
    '{"ram_ret_aon", '{
        '{32'h40510000, 32'h40510fff}
}}};

  // List of Xbar hosts
tl_host_t xbar_hosts[$] = '{
    '{"main", 0, '{
        "pwrmgr_aon",
        "rstmgr_aon",
        "clkmgr_aon",
        "pinmux_aon",
        "padctrl_aon",
        "usbdev_aon",
        "rbox_aon",
        "ram_ret_aon",
        "timer_aon"}}
};
