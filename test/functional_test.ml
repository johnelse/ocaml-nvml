open Unsigned

let separator () = Printf.printf "--------------------\n"

let () =
	Nvml.init ();
	(* Query and print system information. *)
	separator ();
	let driver_version = Nvml.System.get_driver_version () in
	let nvml_version = Nvml.System.get_nvml_version () in
	Printf.printf "System driver version = %s\n" driver_version;
	Printf.printf "NVML version = %s\n" nvml_version;
	(* Query and print device information. *)
	separator ();
	let count = UInt.to_int (Nvml.Device.get_count ()) in
	(match count with
	| 1 -> Printf.printf "There is %d device installed.\n" count
	| _ -> Printf.printf "There are %d devices installed.\n" count);
	for index = 0 to (count - 1) do
		let device = Nvml.Device.get_handle_by_index ~index:(UInt.of_int index) in
		let name = Nvml.Device.get_name ~device in
		let uuid = Nvml.Device.get_uuid ~device in
		let vbios_version = Nvml.Device.get_vbios_version ~device in
		let fan_speed_opt =
			try Some (Nvml.Device.get_fan_speed ~device)
			with Nvml.Error Nvml.Not_supported -> None
		in
		let temperature =
			Nvml.Device.get_temperature ~device
				~sensor_type:Nvml.TemperatureSensors.GPU
		in
		let memory = Nvml.Device.get_memory_info ~device in
		separator ();
		Printf.printf "Device index = %d\n" index;
		Printf.printf "Name = %s\n" name;
		Printf.printf "UUID = %s\n" uuid;
		Printf.printf "VBIOS version = %s\n" vbios_version;
		Printf.printf "Fan speed = %s\n"
			(match fan_speed_opt with
			| Some fan_speed -> (UInt.to_string fan_speed)
			| None -> "N/A");
		Printf.printf "Temperature = %d\n" (UInt.to_int temperature);
		Printf.printf "Memory total = %d\n"
			(ULLong.to_int memory.Nvml.Memory.total);
		Printf.printf "Memory free = %d\n"
			(ULLong.to_int memory.Nvml.Memory.free);
		Printf.printf "Memory used = %d\n"
			(ULLong.to_int memory.Nvml.Memory.used)
	done;
	Nvml.shutdown ()
