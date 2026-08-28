/// A throwaway RSA-2048 pair, generated once with Python's `cryptography`.
///
/// The private half is PKCS#8 (`BEGIN PRIVATE KEY`) because that is what
/// `basic_utils` both emits and parses; a PKCS#1 (`BEGIN RSA PRIVATE KEY`)
/// PEM makes its ASN.1 reader throw.
///
/// [testSignatureBase64] is what the server-side stack produces for
/// `sha256(testMessage)` under PKCS#1 v1.5 — that padding is deterministic, so
/// the Dart client must produce the identical bytes. Pinning it here turns a
/// cross-stack incompatibility into a failing unit test instead of a signature
/// the server silently rejects on a phone.
library;

const testMessage = 'Contenu du contrat.';

const testDigestHex =
    '0548abe5173b9c24cd299687cbd3a30ba341dbb87db808b6f3d7305f9f0728af';

const testSignatureBase64 =
    'S0q4hFJrBwYTfTFzFcCFO7T3v9bJEdRHNoUiaXEJ4KCPHTHf6zssYM1k/D8VoLHyXpQ958KZ'
    'Mun54dNMLDiaPSadE3sM1YLfc+TgL99H+FSCpmxZn1T8TlD6jDlGjqsQO29vYEHTt54PJhyL'
    'uL1bsMxXGGyzFXXlb2qYyWjDxTnkTkIlwq+qSwafQMw3V1vX42LjQi0vwKcDcMtgnTWocrp6'
    'x2VBKs4B4yyY7JQc3s8A+T44rd9v4Iwfnt2r7Q9n3KyPS5JJC6DlbB9Wg+9I83/mviaEBpdK'
    'Hrk6FOyPFajhLXhVZ9/unIW/wn5FQ3eYU0SqQ5TdOF5bDP+ufvLQwg==';

const testPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDU51OTNwR3B60s
iIHslJoYAUPXlbvwSynfqpryvupPzdqH37HKsb7XlnoN6ZCA9YbL48bJejSt9z+7
x/ZglQ8U4Ou8rpUG9bWcQ+aiFSE+mmoq88Waw0Kw6VJGbH82NdXV2VYw8Tvo2lwC
zVo9vjY5zME51zBfTG+++Dj9Ev1XhCtqfU9+cJV7LFUzO/bV0Lm97bPEIUpQhxp7
D1Sb+33quthVQWNxF0V/CNMXu+FBpYjm+UIzyGbAIJwvQyIb0uGj/wnsMw+ObPc3
gP9W3D4ML6JWdYPR2BKm5k4/VBozaPunZ3OjK3Yl+y3fD8X0svQdiw2ncTqKThj3
9QaIClL5AgMBAAECggEAApQaHuQOOaehNn/uE/gcge0ey8JL1ALwxJ+DrOflblNW
MdKNNrILV2Yo5AFx5jEkIogHj6WoMBO67GkHcas2F2qCfTKoGQFZFqwU7DN7+qhj
13O7kVgk3W7aQGBdnttkmAIMph8ZB5YixliUfK5qRj8RiJDef6S1v+Tjl4nerCe3
2diQImm66xJvUBpikxhaeJ48GIZVMbEC/fDv+o29i3k3YidxSFMhKx7rw/QabCI1
bKUNZsv3ZXR7TBrrwC+70rNc9+s121PCejMS58YRE1PTAs+qQi5GitG30f9fPIbx
Q4v+UcYZ/c/7DgPF9pOr97f9itKYqlBIVsNToJ4a4QKBgQDqxaIXOZVNNtlaCYAh
kR0x4i0iXj1xOy9y/771EPRHL3acKscbM3a00xlS6yjgzZnJfiGYcAANeddYkab5
udCQ5BMUBeTUOJzK2Q7xTobiExaK2Y66pShS19fRi6rkZci7GsjPtaT9Nf+t/iM+
3/EJ9D8sRW4XEfMAhUURx8khZQKBgQDoJ38c0aaaiC1moJtco5ye5V9SXi7k0MV6
1nYR9PNQfHNvPf4vB5xinr9lGdL0rhGyGq4mWgaZPENCTu3eMEqO6/Y3UxcAa0RC
h2aPgDb7oCJxgRziH5H4/pPZjVjpYB/TNJ2xw5cPvE0ZOwzfmTJzigZd9bpIofqD
np2jwBU8BQKBgGVs1lcESI0gKgxs2E8oGx3G4crcPd0iPaCH/l5vYakzRyG2lWgZ
9qmuHV2mPHXKPStAc5EgqdUokzEvU5zFeuZtshRPa4mHn60+0ubLDxiyOGXqEXBv
E5meqB1eIokjs/GpY6HgjpPZ9Uic52stYjvzqisdH6+V0I6kBK/myOzFAoGANoJv
mjivwcEPx/UWBZ50++ong5ORtzA97iXE+1pkdxWBlTEdKbXDxnQ3xGlX2xO0G/mf
wmmI+xnnQP5/Y5g7KWvGGB9uWy7UjDp2nmMghdyHudbzDTUUdT5xQLerlMB5OII2
NLMUGSHBiJcQ4r951R8nd5Bm+P7vb1Ai+3vygHECgYAgPOvz202OJKWsFfEjQKID
yy8i3LXy390jiaNgG8k2k6W4+RIpQUORSEc05btyvy7mP/NtJQawjeVo1yyA/ZSf
Ck4f+iktNzA0mNw8EHj1/GdM+Y+4tF8/o/askQHbFLvY87KP7M7xgdKUv3i6pSVO
lbHgKn+a+dFJA65wzwpp1g==
-----END PRIVATE KEY-----''';

const testPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1OdTkzcEdwetLIiB7JSa
GAFD15W78Esp36qa8r7qT83ah9+xyrG+15Z6DemQgPWGy+PGyXo0rfc/u8f2YJUP
FODrvK6VBvW1nEPmohUhPppqKvPFmsNCsOlSRmx/NjXV1dlWMPE76NpcAs1aPb42
OczBOdcwX0xvvvg4/RL9V4Qran1PfnCVeyxVMzv21dC5ve2zxCFKUIcaew9Um/t9
6rrYVUFjcRdFfwjTF7vhQaWI5vlCM8hmwCCcL0MiG9Lho/8J7DMPjmz3N4D/Vtw+
DC+iVnWD0dgSpuZOP1QaM2j7p2dzoyt2Jfst3w/F9LL0HYsNp3E6ik4Y9/UGiApS
+QIDAQAB
-----END PUBLIC KEY-----''';
