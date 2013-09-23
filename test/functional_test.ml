open Ctypes
open Unsigned

let () =
	Nvml.init ();
	let device = Nvml.Device.get_handle_by_index ~index:(UInt.of_int 0) in
	let fan_speed = Nvml.Device.get_fan_speed ~device in
	Printf.printf "Fan speed = %d\n%!" (UInt.to_int fan_speed);
	Nvml.shutdown ()
