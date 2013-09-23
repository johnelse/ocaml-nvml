open Ctypes
open Foreign
open Unsigned

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

let string_of_error' =
	foreign ~from:libnvml "nvmlErrorString" (int @-> returning string)
let string_of_error ~error = string_of_error' (int_of_error error)

let init' = foreign ~from:libnvml "nvmlInit" (void @-> returning int)
let init () = check_error init'

let shutdown' = foreign ~from:libnvml "nvmlShutdown" (void @-> returning int)
let shutdown () = check_error shutdown'

module Util = struct
	let string_of_char_array array =
		let buf = Buffer.create 64 in
		let rec aux array index =
			let c = Array.get array index in
			if c = '\000'
			then Buffer.contents buf
			else begin
				Buffer.add_char buf c;
				aux array (index + 1)
			end
		in
		aux array 0
end

module Device = struct
	type t
	let t : t structure typ = structure "nvmlDevice_t"
	let handle = t *:* uint64_t
	let () = seal t

	let get_count' =
		foreign ~from:libnvml "nvmlDeviceGetCount" (ptr uint @-> returning int)
	let get_count () =
		let count_ptr = allocate uint (UInt.of_int 0) in
		check_error (fun () -> get_count' count_ptr);
		!@ count_ptr

	let get_fan_speed' =
		foreign ~from:libnvml "nvmlDeviceGetFanSpeed"
			(t @-> ptr uint @-> returning int)
	let get_fan_speed ~device =
		let fan_speed_ptr = allocate uint (UInt.of_int 0) in
		check_error (fun () -> get_fan_speed' device fan_speed_ptr);
		!@ fan_speed_ptr

	let get_handle_by_index' =
		foreign ~from:libnvml "nvmlDeviceGetHandleByIndex"
			(uint @-> ptr t @-> returning int)
	let get_handle_by_index ~index =
		let device = make t in
		check_error (fun () -> get_handle_by_index' index (addr device));
		device

	let get_name' =
		foreign ~from:libnvml "nvmlDeviceGetName"
			(t @-> ptr char @-> uint @-> returning int)
	let get_name ~device =
		let length = 64 in
		let name_array = Array.make char length in
		let name_ptr = Array.start name_array in
		check_error (fun () -> get_name' device name_ptr (UInt.of_int length));
		Util.string_of_char_array name_array

	let get_power_usage' =
		foreign ~from:libnvml "nvmlDeviceGetPowerUsage"
			(t @-> ptr uint @-> returning int)
	let get_power_usage ~device =
		let power_usage_ptr = allocate uint (UInt.of_int 0) in
		check_error (fun () -> get_power_usage' device power_usage_ptr);
		!@ power_usage_ptr

	let on_same_board' =
		foreign ~from:libnvml "nvmlDeviceOnSameBoard"
			(t @-> t @-> ptr int @-> returning int)
	let on_same_board ~device1 ~device2 =
		let on_same_board_ptr = allocate int 0 in
		check_error (fun () -> on_same_board' device1 device2 on_same_board_ptr);
		(!@ on_same_board_ptr) <> 0
end
