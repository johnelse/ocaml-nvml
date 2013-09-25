open Ctypes

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

module Memory : sig
	type t
	val t : t structure typ

	val total : (Unsigned.ullong, t structure) field
	val free : (Unsigned.ullong, t structure) field
	val used : (Unsigned.ullong, t structure) field
end

module TemperatureSensors : sig
	type t = GPU
end

module Device : sig
	type t

	val get_count : unit -> Unsigned.uint

	val get_fan_speed : device:t Ctypes.structure -> Unsigned.uint

	val get_handle_by_index : index:Unsigned.uint -> t Ctypes.structure

	val get_handle_by_pci_bus_id : pci_bus_id:string -> t Ctypes.structure

	val get_handle_by_uuid : uuid:string -> t Ctypes.structure

	val get_memory_info : device: t Ctypes.structure -> Memory.t Ctypes.structure

	val get_name : device:t Ctypes.structure -> string

	val get_power_usage : device:t Ctypes.structure -> Unsigned.uint

	val get_serial : device:t Ctypes.structure -> string

	val get_temperature : device:t Ctypes.structure ->
		sensor_type:TemperatureSensors.t -> Unsigned.uint

	val get_uuid : device:t Ctypes.structure -> string

	val get_vbios_version : device:t Ctypes.structure -> string

	val on_same_board : device1:t Ctypes.structure ->
		device2: t Ctypes.structure -> bool
end
