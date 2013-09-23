open Ctypes
open Unsigned

let () =
	Nvml.init ();
	let device = make Nvml.Device.t in
	let (_: int) = Nvml.Device.get_handle_by_index (UInt.of_int 0) (addr device) in
	let fan_speed_ptr = allocate uint (UInt.of_int 0) in
	let (_: int) = Nvml.Device.get_fan_speed device (fan_speed_ptr) in
	Printf.printf "Fan speed = %d\n%!" (UInt.to_int (!@ fan_speed_ptr));
	Nvml.shutdown ()
