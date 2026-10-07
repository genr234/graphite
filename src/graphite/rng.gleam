//// A small seeded RNG (Park–Miller) for decorative randomness in the UI,
//// such as notebook covers. Notebook content uses the Prolog RNG instead.

pub opaque type Rng {
  Rng(state: Int)
}

const modulus = 2_147_483_647

pub fn new(seed: Int) -> Rng {
  let state = seed % { modulus - 1 }
  Rng(case state < 0 {
    True -> -state + 1
    False -> state + 1
  })
}

/// A whole number in `0..n - 1`.
pub fn int(rng: Rng, n: Int) -> #(Int, Rng) {
  let state = rng.state * 48_271 % modulus
  #(state % n, Rng(state))
}

/// True `percent` times out of a hundred.
pub fn chance(rng: Rng, percent: Int) -> #(Bool, Rng) {
  let #(roll, rng) = int(rng, 100)
  #(roll < percent, rng)
}

/// A whole number in `low..high`, inclusive.
pub fn between(rng: Rng, low: Int, high: Int) -> #(Int, Rng) {
  let #(n, rng) = int(rng, high - low + 1)
  #(low + n, rng)
}
