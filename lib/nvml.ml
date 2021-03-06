open Ctypes
open Foreign
open Unsigned

let open_library () =
  Dl.dlopen ~filename:"libnvidia-ml.so" ~flags:[Dl.RTLD_LAZY]

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

module Make (L : (sig val library : Dl.library end)) : API = struct
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

  let int_of_error = function
    | Uninitialized -> 1
    | Invalid_argument -> 2
    | Not_supported -> 3
    | No_permission -> 4
    | Already_initialized -> 5
    | Not_found -> 6
    | Insufficient_size -> 7
    | Insufficient_power -> 8
    | Driver_not_loaded -> 9
    | Timeout -> 10
    | IRQ_issue -> 11
    | Library_not_found -> 12
    | Function_not_found -> 13
    | Corrupted_infoROM -> 14
    | GPU_is_lost -> 15
    | Unknown -> 999

  let check_error f =
    let fail e = raise (Error e) in
    match f () with
    | 0 -> ()
    | 1 -> fail Uninitialized
    | 2 -> fail Invalid_argument
    | 3 -> fail Not_supported
    | 4 -> fail No_permission
    | 5 -> fail Already_initialized
    | 6 -> fail Not_found
    | 7 -> fail Insufficient_size
    | 8 -> fail Insufficient_power
    | 9 -> fail Driver_not_loaded
    | 10 -> fail Timeout
    | 11 -> fail IRQ_issue
    | 12 -> fail Library_not_found
    | 13 -> fail Function_not_found
    | 14 -> fail Corrupted_infoROM
    | 15 -> fail GPU_is_lost
    | _ -> fail Unknown

  let string_of_error' =
    foreign ~from:L.library "nvmlErrorString" (int @-> returning string)
  let string_of_error ~error = string_of_error' (int_of_error error)

  let init' = foreign ~from:L.library "nvmlInit" (void @-> returning int)
  let init () = check_error init'

  let shutdown' = foreign ~from:L.library "nvmlShutdown" (void @-> returning int)
  let shutdown () = check_error shutdown'

  module Util = struct
    (* Extract the contents of the char array into a string. The string will be
     * terminated by the first null character, if one is present. *)
    let string_of_char_array array =
      let buf = Buffer.create 64 in
      let rec aux array index =
        if index >= CArray.length array
        then Buffer.contents buf
        else begin
          let c = CArray.get array index in
          if c = '\000'
          then Buffer.contents buf
          else begin
            Buffer.add_char buf c;
            aux array (index + 1)
          end
        end
      in
      aux array 0
  end

  module System = struct
    (* Bindings to the C functions. *)
    module Foreign = struct
      let get_driver_version =
        foreign ~from:L.library "nvmlSystemGetDriverVersion"
          (ptr char @-> uint @-> returning int)

      let get_nvml_version =
        foreign ~from:L.library "nvmlSystemGetNVMLVersion"
          (ptr char @-> uint @-> returning int)

      let get_process_name =
        foreign ~from:L.library "nvmlSystemGetProcessName"
          (uint @-> ptr char @-> uint @-> returning int)
    end

    (* Functions exposed to the interface. *)
    let get_driver_version () =
      let char_array = CArray.make char 80 in
      let char_ptr = CArray.start char_array in
      check_error (fun () -> Foreign.get_driver_version char_ptr (UInt.of_int 80));
      Util.string_of_char_array char_array

    let get_nvml_version () =
      let char_array = CArray.make char 80 in
      let char_ptr = CArray.start char_array in
      check_error (fun () -> Foreign.get_nvml_version char_ptr (UInt.of_int 80));
      Util.string_of_char_array char_array

    let get_process_name ~pid ~length =
      let char_array = CArray.make char (UInt.to_int length) in
      let char_ptr = CArray.start char_array in
      check_error (fun () -> Foreign.get_process_name pid char_ptr length);
      Util.string_of_char_array char_array
  end

  module ClockType = struct
    type t =
      | Graphics
      | SM
      | Mem

    let t =
      let of_int = function
        | 0 -> Graphics
        | 1 -> SM
        | 2 -> Mem
        | _ -> invalid_arg "ClockType.t"
      in
      let to_int = function
        | Graphics -> 0
        | SM -> 1
        | Mem -> 2
      in
      view ~read:of_int ~write:to_int int
  end

  module ComputeMode = struct
    type t =
      | Default
      | Exclusive_thread
      | Prohibited
      | Exclusive_process

    let t =
      let of_int = function
        | 0 -> Default
        | 1 -> Exclusive_thread
        | 2 -> Prohibited
        | 3 -> Exclusive_process
        | _ -> invalid_arg "ComputeMode.t"
      in
      let to_int = function
        | Default -> 0
        | Exclusive_thread -> 1
        | Prohibited -> 2
        | Exclusive_process -> 3
      in
      view ~read:of_int ~write:to_int int
  end

  module EnableState = struct
    type t =
      | Disabled
      | Enabled

    let t =
      let of_int = function
        | 0 -> Disabled
        | 1 -> Enabled
        | _ -> invalid_arg "EnableState.t"
      in
      let to_int = function
        | Disabled -> 0
        | Enabled -> 1
      in
      view ~read:of_int ~write:to_int int
  end

  module Memory = struct
    type internal_t
    let internal_t : internal_t structure typ = structure "nvmlMemory_t"
    let total = internal_t *:* ullong
    let free = internal_t *:* ullong
    let used = internal_t *:* ullong
    let () = seal internal_t

    type t = {
      total : Unsigned.ullong;
      free : Unsigned.ullong;
      used : Unsigned.ullong;
    }
    let t =
      let of_internal internal = {
        total = getf internal total;
        free = getf internal free;
        used = getf internal used;
      } in
      let to_internal t =
        let internal = make internal_t in
        setf internal total t.total;
        setf internal free t.free;
        setf internal used t.used;
        internal
      in
      view ~read:of_internal ~write:to_internal internal_t

    (* An initialising value for creating non-NULL Memory.t pointers. *)
    let init = {
      total = Unsigned.ULLong.of_int 0;
      free = Unsigned.ULLong.of_int 0;
      used = Unsigned.ULLong.of_int 0;
    }
  end

  module PciInfo = struct
    let nvml_device_pci_bus_id_buffer_size = 16

    type internal_t
    let internal_t : internal_t structure typ = structure "nvmlPciInfo_t"
    let bus_id = internal_t *:* (array nvml_device_pci_bus_id_buffer_size char)
    let domain = internal_t *:* uint
    let bus = internal_t *:* uint
    let device = internal_t *:* uint
    let pci_device_id = internal_t *:* uint
    let pci_subsystem_id = internal_t *:* uint
    let () = seal internal_t

    type t = {
      bus_id: string;
      domain: Unsigned.uint;
      bus: Unsigned.uint;
      device: Unsigned.uint;
      pci_device_id: Unsigned.uint;
      pci_subsystem_id: Unsigned.uint;
    }
    let t =
      let of_internal internal = {
        bus_id = Util.string_of_char_array (getf internal bus_id);
        domain = getf internal domain;
        bus = getf internal bus;
        device = getf internal device;
        pci_device_id = getf internal pci_device_id;
        pci_subsystem_id = getf internal pci_subsystem_id;
      } in
      let to_internal t =
        let internal = make internal_t in
        setf internal domain t.domain;
        setf internal bus t.bus;
        setf internal device t.device;
        setf internal pci_device_id t.pci_device_id;
        setf internal pci_subsystem_id t.pci_subsystem_id;
        internal
      in
      view ~read:of_internal ~write:to_internal internal_t

    let init = {
      bus_id = Bytes.create nvml_device_pci_bus_id_buffer_size;
      domain = UInt.of_int 0;
      bus = UInt.of_int 0;
      device = UInt.of_int 0;
      pci_device_id = UInt.of_int 0;
      pci_subsystem_id = UInt.of_int 0;
    }
  end

  module TemperatureSensors = struct
    type t = GPU

    let t =
      let of_int = function
        | 0 -> GPU
        | _ -> invalid_arg "TemperatureSensors.t"
      in
      let to_int = function
        | GPU -> 0
      in
      view ~read:of_int ~write:to_int int
  end

  module Utilization = struct
    type internal_t
    let internal_t : internal_t structure typ = structure "nvmlUtilization_t"
    let gpu = internal_t *:* uint
    let memory = internal_t *:* uint
    let () = seal internal_t

    type t = {
      gpu : Unsigned.uint;
      memory : Unsigned.uint;
    }
    let t =
      let of_internal internal = {
        gpu = getf internal gpu;
        memory = getf internal memory;
      } in
      let to_internal t =
        let internal = make internal_t in
        setf internal gpu t.gpu;
        setf internal memory t.memory;
        internal
      in
      view ~read:of_internal ~write:to_internal internal_t

    (* An initialising value for creating non-NULL Utilization.t pointers. *)
    let init = {
      gpu = Unsigned.UInt.of_int 0;
      memory = Unsigned.UInt.of_int 0;
    }
  end

  module Device = struct
    type internal_t
    let internal_t : internal_t structure typ = structure "nvmlDevice_t"
    let handle = internal_t *:* uint64_t
    let () = seal internal_t

    type t = {
      handle: Unsigned.uint64;
    }
    let t =
      let of_internal internal = {
        handle = getf internal handle;
      } in
      let to_internal t =
        let internal = make internal_t in
        setf internal handle t.handle;
        internal
      in
      view ~read:of_internal ~write:to_internal internal_t

    (* An initialising value for creating non-NULL Device.t pointers. *)
    let init = {
      handle = Unsigned.UInt64.of_int 0;
    }

    (* Bindings to the C functions. *)
    module Foreign = struct
      let get_clock_info =
        foreign ~from:L.library "nvmlDeviceGetClockInfo"
          (t @-> ClockType.t @-> ptr uint @-> returning int)

      let get_compute_mode =
        foreign ~from:L.library "nvmlDeviceGetComputeMode"
          (t @-> ptr ComputeMode.t @-> returning int)

      let get_count =
        foreign ~from:L.library "nvmlDeviceGetCount" (ptr uint @-> returning int)

      let get_fan_speed =
        foreign ~from:L.library "nvmlDeviceGetFanSpeed"
          (t @-> ptr uint @-> returning int)

      let get_handle_by_index =
        foreign ~from:L.library "nvmlDeviceGetHandleByIndex"
          (uint @-> ptr t @-> returning int)

      let get_handle_by_pci_bus_id =
        foreign ~from:L.library "nvmlDeviceGetHandleByPciBusId"
          (string @-> ptr t @-> returning int)

      let get_handle_by_uuid =
        foreign ~from:L.library "nvmlDeviceGetHandleByUUID"
          (string @-> ptr t @-> returning int)

      let get_max_clock_info =
        foreign ~from:L.library "nvmlDeviceGetMaxClockInfo"
          (t @-> ClockType.t @-> ptr uint @-> returning int)

      let get_memory_info =
        foreign ~from:L.library "nvmlDeviceGetMemoryInfo"
          (t @-> ptr Memory.t @-> returning int)

      let get_name =
        foreign ~from:L.library "nvmlDeviceGetName"
          (t @-> ptr char @-> uint @-> returning int)

      let get_pci_info =
        foreign ~from:L.library "nvmlDeviceGetPciInfo"
          (t @-> ptr PciInfo.t @-> returning int)

      let get_power_usage =
        foreign ~from:L.library "nvmlDeviceGetPowerUsage"
          (t @-> ptr uint @-> returning int)

      let get_persistence_mode =
        foreign ~from:L.library "nvmlDeviceGetPersistenceMode"
          (t @-> ptr EnableState.t @-> returning int)

      let get_power_management_mode =
        foreign ~from:L.library "nvmlDeviceGetPowerManagementMode"
          (t @-> ptr EnableState.t @-> returning int)

      let get_serial =
        foreign ~from:L.library "nvmlDeviceGetSerial"
          (t @-> ptr char @-> uint @-> returning int)

      let get_supported_event_types =
        foreign ~from:L.library "nvmlDeviceGetSupportedEventTypes"
          (t @-> ptr ullong @-> returning int)

      let get_temperature =
        foreign ~from:L.library "nvmlDeviceGetTemperature"
          (t @-> TemperatureSensors.t @-> ptr uint @-> returning int)

      let get_utilization_rates =
        foreign ~from:L.library "nvmlDeviceGetUtilizationRates"
          (t @-> ptr Utilization.t @-> returning int)

      let get_uuid =
        foreign ~from:L.library "nvmlDeviceGetUUID"
          (t @-> ptr char @-> uint @-> returning int)

      let get_vbios_version =
        foreign ~from:L.library "nvmlDeviceGetVbiosVersion"
          (t @-> ptr char @-> uint @-> returning int)

      let on_same_board =
        foreign ~from:L.library "nvmlDeviceOnSameBoard"
          (t @-> t @-> ptr int @-> returning int)

      let set_compute_mode =
        foreign ~from:L.library "nvmlDeviceSetComputeMode"
          (t @-> ComputeMode.t @-> returning int)

      let set_persistence_mode =
        foreign ~from:L.library "nvmlDeviceSetPersistenceMode"
          (t @-> EnableState.t @-> returning int)
    end

    (* Generic calls for common getter patterns. *)
    let get_string_generic ~device ~foreign_fn ~length =
      let char_array = CArray.make char length in
      let char_ptr = CArray.start char_array in
      check_error (fun () -> foreign_fn device char_ptr (UInt.of_int length));
      Util.string_of_char_array char_array

    let get_uint_generic ~device ~foreign_fn =
      let uint_ptr = allocate uint (UInt.of_int 0) in
      check_error (fun () -> foreign_fn device uint_ptr);
      !@ uint_ptr

    (* Functions exposed to the interface. *)
    let get_clock_info ~device ~clock_type =
      let clock_speed_ptr = allocate uint (UInt.of_int 0) in
      check_error
        (fun () -> Foreign.get_clock_info device clock_type clock_speed_ptr);
      !@ clock_speed_ptr

    let get_compute_mode ~device =
      let compute_mode_ptr = allocate ComputeMode.t (ComputeMode.Default) in
      check_error (fun () -> Foreign.get_compute_mode device compute_mode_ptr);
      !@ compute_mode_ptr

    let get_count () =
      let count_ptr = allocate uint (UInt.of_int 0) in
      check_error (fun () -> Foreign.get_count count_ptr);
      !@ count_ptr

    let get_fan_speed ~device =
      get_uint_generic ~device ~foreign_fn:Foreign.get_fan_speed

    let get_handle_by_index ~index =
      let device_ptr = allocate t init in
      check_error (fun () -> Foreign.get_handle_by_index index device_ptr);
      !@ device_ptr

    let get_handle_by_pci_bus_id ~pci_bus_id =
      let device_ptr = allocate t init in
      check_error
        (fun () -> Foreign.get_handle_by_pci_bus_id pci_bus_id device_ptr);
      !@ device_ptr

    let get_handle_by_uuid ~uuid =
      let device_ptr = allocate t init in
      check_error (fun () -> Foreign.get_handle_by_uuid uuid device_ptr);
      !@ device_ptr

    let get_max_clock_info ~device ~clock_type =
      let clock_speed_ptr = allocate uint (UInt.of_int 0) in
      check_error
        (fun () -> Foreign.get_max_clock_info device clock_type clock_speed_ptr);
      !@ clock_speed_ptr

    let get_memory_info ~device =
      let memory_ptr = allocate Memory.t Memory.init in
      check_error (fun () -> Foreign.get_memory_info device memory_ptr);
      !@ memory_ptr

    let get_name ~device =
      get_string_generic ~device ~foreign_fn:Foreign.get_name ~length:64

    let get_pci_info ~device =
      let pci_info_ptr = allocate PciInfo.t PciInfo.init in
      check_error (fun () -> Foreign.get_pci_info device pci_info_ptr);
      !@ pci_info_ptr

    let get_power_usage ~device =
      get_uint_generic ~device ~foreign_fn:Foreign.get_power_usage

    let get_persistence_mode ~device =
      let persistence_mode_ptr = allocate EnableState.t EnableState.Disabled in
      check_error
        (fun () -> Foreign.get_persistence_mode device persistence_mode_ptr);
      !@ persistence_mode_ptr

    let get_power_management_mode ~device =
      let power_management_mode_ptr = allocate EnableState.t EnableState.Disabled in
      check_error
        (fun () ->
          Foreign.get_power_management_mode device power_management_mode_ptr);
      !@ power_management_mode_ptr

    let get_serial ~device =
      get_string_generic ~device ~foreign_fn:Foreign.get_serial ~length:30

    let get_supported_event_types ~device =
      let event_types_ptr = allocate ullong (ULLong.of_int 0) in
      check_error
        (fun () -> Foreign.get_supported_event_types device event_types_ptr);
      !@ event_types_ptr

    let get_temperature ~device ~sensor_type =
      let temperature_ptr = allocate uint (UInt.of_int 0) in
      check_error
        (fun () -> Foreign.get_temperature device sensor_type temperature_ptr);
      !@ temperature_ptr

    let get_utilization_rates ~device =
      let utilization_ptr = allocate Utilization.t Utilization.init in
      check_error (fun () -> Foreign.get_utilization_rates device utilization_ptr);
      !@ utilization_ptr

    let get_uuid ~device =
      get_string_generic ~device ~foreign_fn:Foreign.get_uuid ~length:80

    let get_vbios_version ~device =
      get_string_generic ~device ~foreign_fn:Foreign.get_vbios_version ~length:32

    let on_same_board ~device1 ~device2 =
      let on_same_board_ptr = allocate int 0 in
      check_error
        (fun () -> Foreign.on_same_board device1 device2 on_same_board_ptr);
      (!@ on_same_board_ptr) <> 0

    let set_compute_mode ~device ~mode =
      check_error (fun () -> Foreign.set_compute_mode device mode)

    let set_persistence_mode ~device ~mode =
      check_error (fun () -> Foreign.set_persistence_mode device mode)
  end
end
