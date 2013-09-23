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

module Device : sig
	type t

	val get_count : unit -> Unsigned.uint

	val get_fan_speed : device:t Ctypes.structure -> Unsigned.uint

	val get_handle_by_index : index:Unsigned.uint -> t Ctypes.structure

	val get_name : device:t Ctypes.structure -> string

	val get_power_usage : device:t Ctypes.structure -> Unsigned.uint

	val get_serial : device:t Ctypes.structure -> string

	val get_uuid : device:t Ctypes.structure -> string

	val on_same_board : device1:t Ctypes.structure ->
		device2: t Ctypes.structure -> bool
end
