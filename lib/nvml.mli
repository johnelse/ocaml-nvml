open Ctypes

val open_library : unit -> Dl.library

module type API = sig
  type error =
    | Uninitialized
    | Invalid_argument
    | Not_supported
    | No_permission
    | Already_initialized
    | Not_found
    | Insufficient_size
    | Insufficient_power
    | Driver_not_loaded
    | Timeout
    | IRQ_issue
    | Library_not_found
    | Function_not_found
    | Corrupted_infoROM
    | GPU_is_lost
    | Unknown

  exception Error of error

  val string_of_error : error:error -> string

  val init : unit -> unit

  val shutdown : unit -> unit

  module System : sig
    val get_driver_version : unit -> string

    val get_nvml_version : unit -> string

    val get_process_name : pid:Unsigned.uint -> length:Unsigned.uint -> string
  end

  module ClockType : sig
    type t =
      | Graphics
      | SM
      | Mem
  end

  module ComputeMode : sig
    type t =
      | Default
      | Exclusive_thread
      | Prohibited
      | Exclusive_process
  end

  module EnableState : sig
    type t =
      | Disabled
      | Enabled
  end

  module Memory : sig
    type t = {
      total : Unsigned.ullong;
      free : Unsigned.ullong;
      used : Unsigned.ullong;
    }
  end

  module PciInfo : sig
    type t = {
      bus_id: string;
      domain: Unsigned.uint;
      bus: Unsigned.uint;
      device: Unsigned.uint;
      pci_device_id: Unsigned.uint;
      pci_subsystem_id: Unsigned.uint;
    }
  end

  module TemperatureSensors : sig
    type t = GPU
  end

  module Utilization : sig
    type t = {
      gpu : Unsigned.uint;
      memory : Unsigned.uint;
    }
  end

  module Device : sig
    type t

    val get_clock_info : device:t -> clock_type:ClockType.t -> Unsigned.uint

    val get_compute_mode : device:t -> ComputeMode.t

    val get_count : unit -> Unsigned.uint

    val get_fan_speed : device:t -> Unsigned.uint

    val get_handle_by_index : index:Unsigned.uint -> t

    val get_handle_by_pci_bus_id : pci_bus_id:string -> t

    val get_handle_by_uuid : uuid:string -> t

    val get_max_clock_info : device:t -> clock_type:ClockType.t -> Unsigned.uint

    val get_memory_info : device:t -> Memory.t

    val get_name : device:t -> string

    val get_pci_info : device:t -> PciInfo.t

    val get_power_usage : device:t -> Unsigned.uint

    val get_persistence_mode : device:t -> EnableState.t

    val get_power_management_mode : device:t -> EnableState.t

    val get_serial : device:t -> string

    val get_supported_event_types : device:t -> Unsigned.ullong

    val get_temperature : device:t ->
      sensor_type:TemperatureSensors.t -> Unsigned.uint

    val get_utilization_rates : device:t -> Utilization.t

    val get_uuid : device:t -> string

    val get_vbios_version : device:t -> string

    val on_same_board : device1:t -> device2:t -> bool

    val set_compute_mode : device:t -> mode:ComputeMode.t -> unit

    val set_persistence_mode :device:t -> mode:EnableState.t -> unit
  end
end

module Make : functor (L : (sig val library : Dl.library end)) -> API
