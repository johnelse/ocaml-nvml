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
