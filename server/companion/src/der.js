// Minimal DER / X.509 reader — just enough to verify Apple's StoreKit certificate chain with
// WebCrypto (Cloudflare Workers have no X.509 API). Parses; never trusts: every field used
// for a decision is re-checked by the caller.

export function base64ToBytes(b64) {
  const normalized = b64.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export function bytesToHex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Reads one TLV at `offset`. Returns { tag, start (of value), end, headerStart }. */
export function readTLV(bytes, offset) {
  if (offset >= bytes.length) throw new Error("DER: out of range");
  const tag = bytes[offset];
  let lengthByte = bytes[offset + 1];
  let start = offset + 2;
  let length = lengthByte;
  if (lengthByte & 0x80) {
    const count = lengthByte & 0x7f;
    if (count === 0 || count > 4) throw new Error("DER: unsupported length");
    length = 0;
    for (let i = 0; i < count; i++) length = (length << 8) | bytes[start + i];
    start += count;
  }
  const end = start + length;
  if (end > bytes.length) throw new Error("DER: truncated");
  return { tag, start, end, headerStart: offset };
}

/** Children of a constructed TLV. */
export function children(bytes, tlv) {
  const out = [];
  let offset = tlv.start;
  while (offset < tlv.end) {
    const child = readTLV(bytes, offset);
    out.push(child);
    offset = child.end;
  }
  return out;
}

export function oidToString(bytes, tlv) {
  const v = bytes.subarray(tlv.start, tlv.end);
  const parts = [Math.floor(v[0] / 40), v[0] % 40];
  let value = 0;
  for (let i = 1; i < v.length; i++) {
    value = value * 128 + (v[i] & 0x7f);
    if (!(v[i] & 0x80)) {
      parts.push(value);
      value = 0;
    }
  }
  return parts.join(".");
}

function parseTime(bytes, tlv) {
  const text = new TextDecoder().decode(bytes.subarray(tlv.start, tlv.end));
  // UTCTime YYMMDDHHMMSSZ or GeneralizedTime YYYYMMDDHHMMSSZ
  const full = tlv.tag === 0x17 ? (Number(text.slice(0, 2)) >= 50 ? "19" : "20") + text : text;
  const iso = `${full.slice(0, 4)}-${full.slice(4, 6)}-${full.slice(6, 8)}T${full.slice(8, 10)}:${full.slice(10, 12)}:${full.slice(12, 14)}Z`;
  return Date.parse(iso);
}

/**
 * Parses a DER certificate into the parts needed to verify it:
 * tbs (signed bytes), signatureAlgorithm OID, signature (DER ECDSA), spki (DER),
 * curve OID, validity, and the set of extension OIDs present.
 */
export function parseCertificate(der) {
  const bytes = der instanceof Uint8Array ? der : new Uint8Array(der);
  const cert = readTLV(bytes, 0);
  const [tbs, sigAlg, sigValue] = children(bytes, cert);
  const tbsParts = children(bytes, tbs);
  // tbsCertificate: [0] version?, serial, sigAlg, issuer, validity, subject, spki, [3] extensions?
  let i = tbsParts[0].tag === 0xa0 ? 1 : 0;
  const issuer = tbsParts[i + 2];
  const validity = tbsParts[i + 3];
  const subject = tbsParts[i + 4];
  const spki = tbsParts[i + 5];
  const [notBefore, notAfter] = children(bytes, validity);

  const spkiAlg = children(bytes, children(bytes, spki)[0]);
  const curve = spkiAlg[1] ? oidToString(bytes, spkiAlg[1]) : null;

  const extensionOIDs = new Set();
  const extWrapper = tbsParts.find((p) => p.tag === 0xa3);
  if (extWrapper) {
    const extSeq = children(bytes, extWrapper)[0];
    for (const ext of children(bytes, extSeq)) {
      extensionOIDs.add(oidToString(bytes, children(bytes, ext)[0]));
    }
  }

  const signatureBits = bytes.subarray(sigValue.start + 1, sigValue.end); // skip unused-bits byte
  return {
    tbs: bytes.subarray(tbs.headerStart, tbs.end),
    signatureAlgorithm: oidToString(bytes, children(bytes, sigAlg)[0]),
    signature: signatureBits,
    spki: bytes.subarray(spki.headerStart, spki.end),
    curve,
    notBefore: parseTime(bytes, notBefore),
    notAfter: parseTime(bytes, notAfter),
    issuer: bytes.subarray(issuer.headerStart, issuer.end),
    subject: bytes.subarray(subject.headerStart, subject.end),
    extensionOIDs,
  };
}

/** DER ECDSA signature (SEQUENCE { r, s }) → raw r‖s of `size` bytes each (WebCrypto format). */
export function derSignatureToRaw(der, size) {
  const seq = readTLV(der, 0);
  const [r, s] = children(der, seq);
  const out = new Uint8Array(size * 2);
  for (const [index, part] of [r, s].entries()) {
    let value = der.subarray(part.start, part.end);
    while (value.length > size && value[0] === 0) value = value.subarray(1);
    if (value.length > size) throw new Error("ECDSA: integer too long");
    out.set(value, index * size + (size - value.length));
  }
  return out;
}

export const OID = {
  ecdsaSHA256: "1.2.840.10045.4.3.2",
  ecdsaSHA384: "1.2.840.10045.4.3.3",
  p256: "1.2.840.10045.3.1.7",
  p384: "1.3.132.0.34",
  // Apple's marker extensions for the StoreKit signing chain.
  appleReceiptSigning: "1.2.840.113635.100.6.11.1",
  appleWWDRIntermediate: "1.2.840.113635.100.6.2.1",
};
