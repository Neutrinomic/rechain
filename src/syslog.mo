import SWB "mo:swbstable/Stable";
import T "./types";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";

module {

    public class SysLog({
        _eventlog_mem : SWB.StableData<Text>;
    }) { 

        let _eventlog_cls = SWB.SlidingWindowBuffer<Text>(_eventlog_mem);
        //let _eventlog_cls = SWB.SlidingWindowBuffer<Text>(_eventlog_mem);

        public func add(e: Text) {
     
            ignore _eventlog_cls.add(Int.toText(Time.now()) # " : " # e);
            if (_eventlog_cls.len() > 1000) { // Max 1000
                _eventlog_cls.delete(1); // Delete 1 element from the beginning
            };

        };

        public func get() : [?Text] {
          let start = _eventlog_cls.start();

          Array.tabulate(
                _eventlog_cls.len(),
                func(i : Nat) : ?Text {
                    _eventlog_cls.getOpt(start + i);
                },
            );
        };

    }
}