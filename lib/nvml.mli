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

module ComputeMode : sig
	type t =
		| Default
		| Exclusive_thread
		| Prohibited
		| Exclusive_process
end

module Memory : sig
	type t

	val total : (Unsigned.ullong, t structure) field
	val free : (Unsigned.ullong, t structure) field
	val used : (Unsigned.ullong, t structure) field
end

module TemperatureSensors : sig
	type t = GPU
end

module Utilization : sig
	type t

	val gpu : (Unsigned.uint, t structure) field
	val memory : (Unsigned.uint, t structure) field
end

module Device : sig
	type t

	val get_compute_mode : device:t -> ComputeMode.t

	val get_count : unit -> Unsigned.uint

	val get_fan_speed : device:t -> Unsigned.uint

	val get_handle_by_index : index:Unsigned.uint -> t

	val get_handle_by_pci_bus_id : pci_bus_id:string -> t

	val get_handle_by_uuid : uuid:string -> t

	val get_memory_info : device:t -> Memory.t Ctypes.structure

	val get_name : device:t -> string

	val get_power_usage : device:t -> Unsigned.uint

	val get_serial : device:t -> string

	val get_temperature : device:t ->
		sensor_type:TemperatureSensors.t -> Unsigned.uint

	val get_utilization_rates : device:t -> Utilization.t Ctypes.structure

	val get_uuid : device:t -> string

	val get_vbios_version : device:t -> string

	val on_same_board : device1:t -> device2:t -> bool

	val set_compute_mode : device:t -> mode:ComputeMode.t -> unit
end
