open Ctypes
open Foreign

let libnvml = Dl.dlopen ~filename:"libnvidia-ml.so" ~flags:[Dl.RTLD_LAZY]

module Return = struct
	type t
	let t : t union typ = union "nvmlReturn_t"

	let to_string = foreign ~from:libnvml "nvmlErrorString" (int @-> returning string)
end

let init = foreign ~from:libnvml "nvmlInit" (void @-> returning int)
let shutdown = foreign ~from:libnvml "nvmlShutdown" (void @-> returning int)

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
