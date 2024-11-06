import MU "mo:mosup";

module {
    public module NoArchive {

        public func new() : MU.MemShell<Mem> = MU.new<Mem>({
            var lastIndex = 0;
        });

        public type Mem = {
            var lastIndex : Nat;
        };

    };
};
