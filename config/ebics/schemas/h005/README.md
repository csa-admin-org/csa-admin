# EBICS H005 schemas

Official EBICS 3.0 H005 XML schemas used at runtime to validate response and order-data payloads, and in tests to validate generated requests.

- Source URL: https://www.ebics.de/fileadmin/unsecured/specification/schema_current/EBICS_3.0_schema_H005FinalVersion07-08-2017.zip
- SHA-256: `e2cec4c8b0a43c325e0e6a84f969834ac47f921cdfa1fd59f9784eb46599863d`
- Retrieved for the CSA Admin EBICS 3.0 / H005 / BTF rollout. The zip itself is not retained; these vendored files are the runtime copy.

Do not download schemas at runtime or during tests. Update these vendored files only when intentionally moving to a newer official EBICS schema package, and update this README with the new source/checksum.
