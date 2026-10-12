// Verifies a StoreKit 2 signed transaction (the app sends `Transaction.jwsRepresentation`).
// The x5c chain must end in a pinned Apple root, each certificate must be signed by the next,
// carry Apple's marker extensions and be in date; the JWS must be signed by the leaf; and the
// transaction must be an active subscription to one of our products, for our bundle.

import { OID, base64ToBytes, bytesToHex, derSignatureToRaw, parseCertificate } from "./der.js";

/** SHA-256 of Apple Root CA - G3 (https://www.apple.com/certificateauthority/). */
export const APPLE_ROOT_CA_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

export class VerificationError extends Error {}

const CURVES = { [OID.p256]: { name: "P-256", size: 32 }, [OID.p384]: { name: "P-384", size: 48 } };
const HASHES = { [OID.ecdsaSHA256]: "SHA-256", [OID.ecdsaSHA384]: "SHA-384" };

async function importKey(cert) {
  const curve = CURVES[cert.curve];
  if (!curve) throw new VerificationError("unsupported key curve");
  const key = await crypto.subtle.importKey("spki", cert.spki, { name: "ECDSA", namedCurve: curve.name }, false, ["verify"]);
  return { key, size: curve.size };
}

async function verifySignedBy(child, parent) {
  const hash = HASHES[child.signatureAlgorithm];
  if (!hash) throw new VerificationError("unsupported signature algorithm");
  const { key, size } = await importKey(parent);
  const raw = derSignatureToRaw(child.signature, size);
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash }, key, raw, child.tbs);
  if (!ok) throw new VerificationError("certificate signature invalid");
}

function sameBytes(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

function decodeJSON(part) {
  return JSON.parse(new TextDecoder().decode(base64ToBytes(part)));
}

/**
 * @param {string} jws
 * @param {{ rootFingerprints: string[], bundleId: string, productIds: string[],
 *           environments: string[], now?: number, requireAppleExtensions?: boolean }} options
 * @returns {Promise<{ originalTransactionId: string, productId: string, expiresDate: number, environment: string }>}
 */
export async function verifySubscription(jws, options) {
  const now = options.now ?? Date.now();
  const parts = typeof jws === "string" ? jws.split(".") : [];
  if (parts.length !== 3) throw new VerificationError("malformed JWS");
  let header;
  try {
    header = decodeJSON(parts[0]);
  } catch {
    throw new VerificationError("malformed header");
  }
  if (header.alg !== "ES256" || !Array.isArray(header.x5c) || header.x5c.length < 3) {
    throw new VerificationError("unexpected JWS header");
  }

  const ders = header.x5c.slice(0, 3).map((b64) => base64ToBytes(b64));
  const [leaf, intermediate, root] = ders.map((der) => parseCertificate(der));

  const rootHash = bytesToHex(new Uint8Array(await crypto.subtle.digest("SHA-256", ders[2])));
  if (!options.rootFingerprints.includes(rootHash)) throw new VerificationError("untrusted root");

  for (const cert of [leaf, intermediate, root]) {
    if (!(cert.notBefore <= now && now <= cert.notAfter)) throw new VerificationError("certificate out of date");
  }
  if (!sameBytes(leaf.issuer, intermediate.subject) || !sameBytes(intermediate.issuer, root.subject)) {
    throw new VerificationError("broken chain");
  }
  if (options.requireAppleExtensions !== false) {
    if (!leaf.extensionOIDs.has(OID.appleReceiptSigning)) throw new VerificationError("leaf is not a StoreKit signing certificate");
    if (!intermediate.extensionOIDs.has(OID.appleWWDRIntermediate)) throw new VerificationError("intermediate is not Apple WWDR");
  }
  await verifySignedBy(intermediate, root);
  await verifySignedBy(leaf, intermediate);

  // The JWS itself, signed by the leaf (ES256: raw r‖s, base64url).
  const { key } = await importKey(leaf);
  const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = base64ToBytes(parts[2]);
  if (signature.length !== 64) throw new VerificationError("bad JWS signature length");
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, signature, signed);
  if (!ok) throw new VerificationError("JWS signature invalid");

  let payload;
  try {
    payload = decodeJSON(parts[1]);
  } catch {
    throw new VerificationError("malformed payload");
  }
  if (payload.bundleId !== options.bundleId) throw new VerificationError("wrong app");
  if (!options.productIds.includes(payload.productId)) throw new VerificationError("not a companion product");
  if (payload.type !== "Auto-Renewable Subscription") throw new VerificationError("not a subscription");
  if (payload.revocationDate) throw new VerificationError("revoked");
  if (!(typeof payload.expiresDate === "number" && payload.expiresDate > now)) throw new VerificationError("expired");
  if (!options.environments.includes(payload.environment)) throw new VerificationError("environment not allowed");

  return {
    originalTransactionId: String(payload.originalTransactionId),
    productId: payload.productId,
    expiresDate: payload.expiresDate,
    environment: payload.environment,
  };
}
