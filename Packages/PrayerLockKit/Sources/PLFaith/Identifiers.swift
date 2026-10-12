import PLCore

public enum FaithTag {}
public enum TraditionTag {}
public enum FocusTag {}
public enum SourceWorkTag {}
public enum EditionTag {}
public enum ThemeTag {}
public enum OccasionTag {}

/// e.g. `christianity`, `islam`, `hinduism`.
public typealias FaithID = Identifier<FaithTag>
/// e.g. `christianity.catholic`, `islam.sunni`, `hinduism.shaiva`.
public typealias TraditionID = Identifier<TraditionTag>
/// A deity, divine aspect, or devotional focus where a faith uses that concept, e.g. `hinduism.shiva`.
public typealias FocusID = Identifier<FocusTag>
/// A source work, e.g. `bible`, `quran`, `rigveda`.
public typealias SourceWorkID = Identifier<SourceWorkTag>
/// A specific edition/translation of a source work, e.g. `bible.web`.
public typealias EditionID = Identifier<EditionTag>
/// A content theme, e.g. `peace`, `gratitude`, `strength`.
public typealias ThemeID = Identifier<ThemeTag>
/// A religious occasion or observance, e.g. `christianity.easter`, `islam.ramadan`.
public typealias OccasionID = Identifier<OccasionTag>
