import Vec "mo:vector";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";

module {
    public func encodeBigEndian(nat : Nat) : Blob {
        var tempNat = nat;
        var bitCount = 0;
        while (tempNat > 0) {
            bitCount += 1;
            tempNat /= 2;
        };
        let byteCount = (bitCount + 7) / 8;

        var buffer = Vec.init<Nat8>(byteCount, 0);
        for (i in Iter.range(0, byteCount -1)) {
            let byteValue = Nat.div(nat, Nat.pow(256, i)) % 256;
            Vec.put(buffer, i, Nat8.fromNat(byteValue));
        };

        Vec.reverse<Nat8>(buffer);
        return Blob.fromArray(Vec.toArray<Nat8>(buffer));
    };

};
