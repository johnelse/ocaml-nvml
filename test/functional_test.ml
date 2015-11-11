open Unsigned

let separator () = Printf.printf "--------------------\n"

let () =
  let library = Nvml.open_library () in
  let module NVML = Nvml.Make(struct let library = library end) in
  NVML.init ();
  (* Query and print system information. *)
  separator ();
  let driver_version = NVML.System.get_driver_version () in
  let nvml_version = NVML.System.get_nvml_version () in
  Printf.printf "System driver version = %s\n" driver_version;
  Printf.printf "NVML version = %s\n" nvml_version;
  (* Query and print device information. *)
  separator ();
  let count = UInt.to_int (NVML.Device.get_count ()) in
  (match count with
  | 1 -> Printf.printf "There is %d device installed.\n" count
  | _ -> Printf.printf "There are %d devices installed.\n" count);
  for index = 0 to (count - 1) do
    let device = NVML.Device.get_handle_by_index ~index:(UInt.of_int index) in
    let name = NVML.Device.get_name ~device in
    let uuid = NVML.Device.get_uuid ~device in
    let vbios_version = NVML.Device.get_vbios_version ~device in
    let fan_speed_opt =
      try Some (NVML.Device.get_fan_speed ~device)
      with NVML.Error NVML.Not_supported -> None
    in
    let temperature =
      NVML.Device.get_temperature ~device
        ~sensor_type:NVML.TemperatureSensors.GPU
    in
    let memory = NVML.Device.get_memory_info ~device in
    let pci_info = NVML.Device.get_pci_info ~device in
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
      (ULLong.to_int memory.NVML.Memory.total);
    Printf.printf "Memory free = %d\n"
      (ULLong.to_int memory.NVML.Memory.free);
    Printf.printf "Memory used = %d\n"
      (ULLong.to_int memory.NVML.Memory.used);
    Printf.printf "PCI address = %s\n" pci_info.NVML.PciInfo.bus_id
  done;
  NVML.shutdown ()
