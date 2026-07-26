# Purchase safety

Product and cart state are checked before add/checkout. The exact product,
quantity, payment method and review page must be verified. Final submission is
disabled by default, requires explicit `allowFinalSubmit: true`, and is clicked
once. Card/CVV values are transient and cleared in `finally`; 3DS is detected,
never bypassed. An unknown order outcome returns a typed state without retry.

