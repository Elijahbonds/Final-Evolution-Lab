/**
 * StateMachine — minimal, mode-agnostic FSM helper.
 *
 * States are plain objects: { enter?(ctx, from), update?(ctx, dt), exit?(ctx, to) }.
 * The machine never allocates during update(); transitions are explicit
 * (modes decide when), which keeps mode rules out of shared code.
 */
export class StateMachine {
  /**
   * @param {{ initial: string,
   *           states: Record<string, { enter?: Function, update?: Function, exit?: Function }>,
   *           ctx?: object,
   *           onTransition?: (from: string, to: string) => void }} opts
   */
  constructor({ initial, states, ctx = {}, onTransition }) {
    this.states = states;
    this.ctx = ctx;
    this.onTransition = onTransition ?? null;
    this.current = initial;
    this.timeInState = 0;
    this.previous = null;
    states[initial]?.enter?.(ctx, null);
  }

  /** @returns {boolean} true if the transition happened */
  transition(to) {
    if (to === this.current || !this.states[to]) return false;
    const from = this.current;
    this.states[from]?.exit?.(this.ctx, to);
    this.previous = from;
    this.current = to;
    this.timeInState = 0;
    this.states[to]?.enter?.(this.ctx, from);
    if (this.onTransition) this.onTransition(from, to);
    return true;
  }

  /** Advance the active state. Call from the fixed-timestep update. */
  update(dt) {
    this.timeInState += dt;
    this.states[this.current]?.update?.(this.ctx, dt);
  }

  is(name) { return this.current === name; }
}

export default StateMachine;
