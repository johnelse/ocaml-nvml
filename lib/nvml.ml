open Ctypes
open Foreign

let libnvml = Dl.dlopen ~filename:"libnvidia-ml.so" ~flags:[Dl.RTLD_LAZY]

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

let string_of_error error =
	let string_of_error' =
		foreign ~from:libnvml "nvmlErrorString" (int @-> returning string)
	in
	string_of_error' (int_of_error error)

let init () =
	let init' = foreign ~from:libnvml "nvmlInit" (void @-> returning int) in
	check_error init'

let shutdown () =
	let shutdown' =
		foreign ~from:libnvml "nvmlShutdown" (void @-> returning int)
	in
	check_error shutdown'

module Device = struct
	type t
	let t : t structure typ = structure "nvmlDevice_t"
	let handle = t *:* uint64_t
	let () = seal t

	let get_count = foreign ~from:libnvml "nvmlDeviceGetCount"
		(ptr uint @-> returning int)

	let get_handle_by_index = foreign ~from:libnvml "nvmlDeviceGetHandleByIndex"
		(uint @-> ptr t @-> returning int)

	let get_fan_speed = foreign ~from:libnvml "nvmlDeviceGetFanSpeed"
		(t @-> ptr uint @-> returning int)
end
