/**
 * The Pareto frontier of a set of trade-off points.
 *
 * A frontier answers one question and no more: which arms is nothing on this chart better
 * than on both axes at once. It is not a ranking — the members are not ordered by merit,
 * they are the set nothing dominates — which is why a page can draw one without publishing
 * the single score DEC-005 refuses.
 */

/** One point on a trade-off chart: what it is, and where it sits. Lower `x`, higher `y`. */
export type ParetoPoint = {
  readonly id: string;
  readonly x: number;
  readonly y: number;
};

/**
 * The members of the frontier, cheapest first.
 *
 * Ties on `x` collapse to the best `y`: two arms at the same cost are one position on the
 * chart, and keeping both would put a vertical segment on the frontier, which reads as a
 * trade-off where there is none.
 *
 * A frontier of fewer than two members is returned as what it is. The caller draws no line
 * through one point and says which member it is, instead of showing a chart with an
 * unexplained absence. That is the live wall-clock shape: ponytail is both faster and
 * better than every other arm, so nothing else is on the frontier at all. An earlier
 * version of this comment gave a different reason — that the other arms "sit at the same x
 * to rendering precision" — which was read off a rounded display and is false: baseline is
 * 47.0345s against ponytail's 46.9836s. The conclusion survived its premise by luck.
 *
 * @throws {RangeError} no points at all — a frontier over nothing is not an empty frontier,
 * it is a question that was never asked.
 */
export const paretoFrontier = ({
  points,
}: {
  points: readonly ParetoPoint[];
}): readonly ParetoPoint[] => {
  if (points.length === 0) {
    throw new RangeError('a frontier needs at least one point');
  }

  const byCost = [...points].sort((left, right) => left.x - right.x || right.y - left.y);
  const members: ParetoPoint[] = [];

  for (const point of byCost) {
    const best = members[members.length - 1];

    if (best === undefined || point.y > best.y) {
      members.push(point);
    }
  }

  return members;
};
