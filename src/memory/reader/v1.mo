import MU "mo:mosup";

module {
    public module Reader {

        public func new() : MU.MemShell<Mem> = MU.new<Mem>({
            var last_indexed_tx = 0;
        });

        public type Mem = {
             var last_indexed_tx : Nat;
        };

    };
};
