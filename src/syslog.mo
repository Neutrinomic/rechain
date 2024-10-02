import SWB "mo:swbstable/Stable";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Int "mo:base/Int";

module {

    public class SysLog({
        _eventlog_mem : SWB.StableData<Text>;
    }) { 

        let _eventlog_cls = SWB.SlidingWindowBuffer<Text>(_eventlog_mem);

        public func add(e: Text) {
     
            ignore _eventlog_cls.add(Int.toText(Time.now()) # " : " # e);
            if (_eventlog_cls.len() > 1000) {
                _eventlog_cls.delete(1); 
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