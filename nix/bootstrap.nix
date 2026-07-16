let
  /**
  Returns a value computed by calling a function `f` with the value returned by
  it as its argument.

  This allows the value returned by `f` to reference itself via `f`'s argument.

  The value returned by `fix`, `f`'s argument, and `f`'s return value (which
  are all the same value) are referred to as a "fixpoint". `f`'s argument is
  conventionally named `self` or `final`.
  */
  fix = f: let x = f x; in x;
in
fix (self: {
  inherit fix;

  /**
  Returns a fixpoint with updates from an "override" `o` applied to it with
  `//` by calling `f` with the updated fixpoint as its argument. An override
  (and thus `o`) is a function from the updated fixpoint to a function from
  the original fixpoint to the attribute set to be used on the right-hand-side
  of `//` (with the original fixpoint on the left-hand-side). The fixpoint
  returned by `f` must be an attribute set.

  This allows the fixpoint returned by `f` to reference the updated version of
  itself via `f`'s argument, and for the override to compute the attributes to
  update and their new values based on the updated and original version of the
  fixpoint returned by `f`.

  The argument to the override's first function is conventionally named
  `final`, and the argument to its second function is conventionally named
  `prev`. `f`'s argument is conventionally named `self` or `final`.
  */
  fixWithOverride = o: f: (final:
    let
      prev = f final;
    in
    prev // o final prev
  );

  /**
  Returns an override based on `x`. `x` must be either:

  1. A non-function value.
  2. A function to a non-function value. The function's argument is
     conventionally named `prev`.
  3. A function to a function to a value. The first function's argument is
     conventionally named `final`, and the second function's argument is
     conventionally named `prev`.

  This allows for more ergonomic construction of overrides for use with
  `fixWithOverride`.
  */
  toOverride = x:
    if builtins.isFunction x then
      final: prev:
      let
        xWithPrev = x prev;
      in
      if builtins.isFunction xWithPrev then
        x final prev
      else
        xWithPrev
    else
      final: prev: x;

  /**
  Returns the fixpoint attribute set returned by `f` (see the `fix` function
  for details) after updating it with the attributes from `e` and an `override`
  attribute (in that order). The `override` attribute is a function that takes
  a value that can be converted into an override (see `toOverride` for details),
  computes the fixpoint with the override (see `fixWithOverride` for details),
  updates it with the attributes from `e` and an `override` attribute (in that
  order), then returns it. Notably, attempting to update the attributes from
  `e` and the `override` attribute with the override will have no effect, and
  updating `override` with `e` will have no effect.

  This allows for evaluating a fixpoint attribute set, making it overridable,
  and optionally adding extra attributes to it.
  */
  fixOverridableWith = e: f: (self.fix f) // e // {
    override = o:
      self.fixOverridableWith e (self.fixWithOverride (self.toOverride o) f);
  };

  /**
  Returns the fixpoint attribute set returned by `f` after updating it with an
  `override` attribute. See `fixOverridableWith` for details.

  This allows for evaluating a fixpoint attribute set and making it overridable.
  */
  fixOverridable = f: self.fixOverridableWith {} f;

  /**
  Returns a Sprinkle computed from the fixpoint attribute set returned by `f`.
  See `fixOverridableWith` for details.

  This allows for evaluating a fixpoint attribute set, making it overridable,
  and declaring that it is a Sprinkle by setting the `type` attribute to
  `"sprinkle"`.

  This function does not check if the Sprinkles conventions are followed.
  */
  new = f: self.fixOverridableWith {
    type = "not-sprinkle";
    version = 1;
  } f;
})