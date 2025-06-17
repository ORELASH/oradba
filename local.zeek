@load tuning/defaults
@load frameworks/communication/listen

redef LogAscii::use_json = T;
redef LogAscii::json_timestamps = JSON::TS_EPOCH;

redef Site::local_nets += { 192.168.0.0/16 };
redef Site::interface = "eth0";
