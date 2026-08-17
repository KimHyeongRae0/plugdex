/**
 * The shape of a listing, and the difference between what an author says and what we say.
 *
 * SRC-01 requires every listed pack to link upstream, name its author, and record how they
 * can ask to be removed. The type makes the harder half of that enforceable: an
 * attribution value is never a bare string, because a bare string cannot say whether it
 * came from the author's own manifest or from us. `upstream` is the author's declaration
 * about themselves, quoted. `curated` is our claim about someone else, and it carries the
 * reason we had to make it.
 *
 * Why that distinction earns a place in the type rather than a comment: one measured pack
 * is commonly called "Karpathy's skills" and its own manifest names a different author
 * entirely. Listing it under the famous name would be misattribution on the front page of
 * a provenance site, and the only defence that scales is deriving the field instead of
 * typing it.
 */

/** An attribution value together with where it came from. */
export type Attributed =
  | { readonly from: 'upstream'; readonly value: string }
  | { readonly from: 'curated'; readonly value: string; readonly why: string };

/**
 * Where `claude plugin install` fetches a pack from.
 *
 * Only the `github` form exists here on purpose. The CLI's marketplace context does not
 * support the `git`/`url` form, and a union of one is what makes that unrepresentable
 * rather than merely discouraged — see the compile pair under `test/fixtures/`.
 */
export interface InstallSource {
  readonly source: 'github';
  readonly repo: string;
}

/**
 * A star count and the moment it was true.
 *
 * A bare number would be a claim with no expiry, and stars move. Recording when it was
 * read is what lets a reader decide whether to believe it, which is the same discipline
 * the measurement records follow.
 */
export interface StarsAtRecordTime {
  readonly count: number;
  /** ISO date the count was read. */
  readonly readAt: string;
}

/**
 * Where a recorded manifest came from.
 *
 * DEC-011 records a pack's manifest verbatim so our listing can be audited against it.
 * Without the commit it was read from, the audit has no fixed point: the upstream file
 * changes and the recorded copy silently becomes a claim about a version nobody can name.
 */
export interface ManifestSource {
  readonly repo: string;
  readonly commit: string;
  readonly path: string;
  readonly readAt: string;
  readonly stars: number;
  readonly receipt: RetrievalReceipt;
}

/**
 * How a recorded figure was obtained.
 *
 * The star count comes off a network read that no gate can repeat, so the value alone is a
 * number a reader can neither reproduce nor refute. SRC-01g requires the receipt, and the
 * requirement belongs in the type rather than only in the gate's inline check: `fullName`
 * is recorded from the same response so a redirected repository cannot attach one
 * project's popularity to another project's listing.
 */
export interface RetrievalReceipt {
  readonly starsCommand: string;
  readonly commitCommand?: string;
  readonly readAt: string;
  readonly fullName: string;
  readonly forks?: number;
  readonly note?: string;
}

/** How a pack came to be listed, and how its author can have that undone. */
export interface ListingProvenance {
  readonly how: 'measured' | 'requested' | 'curated';
  readonly note: string;
}

/** One listed pack. Every SRC-01 field is required; none of them is optional. */
export interface PackEntry {
  /** Matches the arm id in the measurement corpus, so the AC-6 join is total. */
  readonly packId: string;
  readonly displayName: string;
  readonly author: Attributed;
  readonly upstreamRepo: Attributed;
  readonly license: Attributed;
  readonly stars: StarsAtRecordTime;
  readonly installSource: InstallSource;
  readonly listingProvenance: ListingProvenance;
  readonly optOutContact: string;
}

/** The manifest fields we read from a pack's own `.claude-plugin/plugin.json`. */
export interface UpstreamManifest {
  readonly name?: string;
  readonly author?:
    string | { readonly name?: string; readonly url?: string; readonly email?: string };
  readonly repository?: string | null;
  readonly homepage?: string | null;
  readonly license?: string | null;
}
