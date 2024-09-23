# Changelog

## [4.3.0](https://github.com/ethpandaops/ethereum-package/compare/4.2.0...4.3.0) (2024-09-23)


### Features

* add prefunded accounts ([#752](https://github.com/ethpandaops/ethereum-package/issues/752)) ([1be7efa](https://github.com/ethpandaops/ethereum-package/commit/1be7efa028d5b72837a9c4b5de5b70e102e2f166))
* dora - show more infos about all peers on client pages ([#760](https://github.com/ethpandaops/ethereum-package/issues/760)) ([c77d95f](https://github.com/ethpandaops/ethereum-package/commit/c77d95fe21deb9dd09481998d2e39f46b148f146))


### Bug Fixes

* `metrics-host-allowlist` for Teku ([#765](https://github.com/ethpandaops/ethereum-package/issues/765)) ([ad75fcc](https://github.com/ethpandaops/ethereum-package/commit/ad75fcce4aa3dcd0064a6d538462587e430478a0))
* built in validator lifecycle test for assertoor ([#763](https://github.com/ethpandaops/ethereum-package/issues/763)) ([6f868cc](https://github.com/ethpandaops/ethereum-package/commit/6f868ccf26abf341a83bc96569dea0fa890f90f7))
* explicitly set client contexts ([#755](https://github.com/ethpandaops/ethereum-package/issues/755)) ([94dc531](https://github.com/ethpandaops/ethereum-package/commit/94dc531e332f4fd4466a9473dfec328a3a681b01))
* no default resource limits ([#768](https://github.com/ethpandaops/ethereum-package/issues/768)) ([4c4831b](https://github.com/ethpandaops/ethereum-package/commit/4c4831bc509ae580f68b85c2c5b469d454586def))
* prysm gRPC removal - use http server instead for keymanager ([#761](https://github.com/ethpandaops/ethereum-package/issues/761)) ([ba91174](https://github.com/ethpandaops/ethereum-package/commit/ba911745b5e6cdc0216c5394394605d274ce70ef))
* remove epoch checker for goomy ([#754](https://github.com/ethpandaops/ethereum-package/issues/754)) ([f124bbf](https://github.com/ethpandaops/ethereum-package/commit/f124bbf96847ec08d3aa7e8b65df336ef6722475))
* remove exp RPC API namespace flag from nimbus-eth1 configuration ([#767](https://github.com/ethpandaops/ethereum-package/issues/767)) ([8fec454](https://github.com/ethpandaops/ethereum-package/commit/8fec454f7af0733277336fc3f06376442b7b4fa4))
* reth-builder volume claim ([#771](https://github.com/ethpandaops/ethereum-package/issues/771)) ([4570328](https://github.com/ethpandaops/ethereum-package/commit/4570328e47b6ef5a59a47635f6c58acd3f8ad2d1))
* update dora config for latest release & remove custom images ([#748](https://github.com/ethpandaops/ethereum-package/issues/748)) ([a433c50](https://github.com/ethpandaops/ethereum-package/commit/a433c50e1c61dd20a6c28dcebfde704c136ddb69))

## [4.2.0](https://github.com/ethpandaops/ethereum-package/compare/4.1.0...4.2.0) (2024-08-19)


### Features

* add customizable configuraiton for prometheus retention ([#745](https://github.com/ethpandaops/ethereum-package/issues/745)) ([6c02dfe](https://github.com/ethpandaops/ethereum-package/commit/6c02dfee67e239650f9f21786ff5c976770a733b))
* add genesis_gaslimit param configuration ([#726](https://github.com/ethpandaops/ethereum-package/issues/726)) ([a4ba9a6](https://github.com/ethpandaops/ethereum-package/commit/a4ba9a65852411db43dbcf3c727c9ad52040e482))
* Add Lighthouse PeerDAS Dashboard ([#736](https://github.com/ethpandaops/ethereum-package/issues/736)) ([ffbfde2](https://github.com/ethpandaops/ethereum-package/commit/ffbfde23f2e58350145ab48d0dbce5e245385ab5))
* add peerdas-electra-support ([#740](https://github.com/ethpandaops/ethereum-package/issues/740)) ([663e7e6](https://github.com/ethpandaops/ethereum-package/commit/663e7e654b81fb623a1fa486ccf7092ba2e39d80))
* add profiling for prysm ([#722](https://github.com/ethpandaops/ethereum-package/issues/722)) ([7dc6660](https://github.com/ethpandaops/ethereum-package/commit/7dc66606f5d5f86d4ef394bc70fe2e936cd55c75))
* add sanity check ([#710](https://github.com/ethpandaops/ethereum-package/issues/710)) ([b824cac](https://github.com/ethpandaops/ethereum-package/commit/b824cac89ca2c78604c82544888a89c0c1d3aa80))
* enable dora pprof ([#743](https://github.com/ethpandaops/ethereum-package/issues/743)) ([2b7be9a](https://github.com/ethpandaops/ethereum-package/commit/2b7be9a27c516b17322e8028c23813620bfc6afe))
* generate keys if not default key is used ([#707](https://github.com/ethpandaops/ethereum-package/issues/707)) ([2d1cab5](https://github.com/ethpandaops/ethereum-package/commit/2d1cab5317dac62524601f392a4a62a7c3a88b80))
* lodestar persists invalid ssz objects by default ([#730](https://github.com/ethpandaops/ethereum-package/issues/730)) ([5a45991](https://github.com/ethpandaops/ethereum-package/commit/5a459914327e33c426e82df62af6336970857f08))
* update egg config parameters ([#737](https://github.com/ethpandaops/ethereum-package/issues/737)) ([78c2bc7](https://github.com/ethpandaops/ethereum-package/commit/78c2bc77caaf814cf360499b6b61337ea7eb7099))


### Bug Fixes

* add debug ns to nethermind ([#732](https://github.com/ethpandaops/ethereum-package/issues/732)) ([372bb52](https://github.com/ethpandaops/ethereum-package/commit/372bb521525948bc0a97a1999e6d233cb2792626))
* allow vc properties in participants_matrix.cl ([#715](https://github.com/ethpandaops/ethereum-package/issues/715)) ([c8b9b19](https://github.com/ethpandaops/ethereum-package/commit/c8b9b19c045f6075fa02f9abf8f761a5a8056ba3))
* besu devnet schedule ([#734](https://github.com/ethpandaops/ethereum-package/issues/734)) ([28b67cd](https://github.com/ethpandaops/ethereum-package/commit/28b67cd17a6f0abf80c46821465872d4006f9277))
* blobscan redis dependency ([#712](https://github.com/ethpandaops/ethereum-package/issues/712)) ([0ed1c9c](https://github.com/ethpandaops/ethereum-package/commit/0ed1c9c8e974f7c6900f68679602d95cfcb17831))
* change churn limit default for pectra tests ([#747](https://github.com/ethpandaops/ethereum-package/issues/747)) ([8109054](https://github.com/ethpandaops/ethereum-package/commit/8109054e20121092ad5ad3eebbf1a16a20677887))
* correctly apply extra params if builder is enabled ([#725](https://github.com/ethpandaops/ethereum-package/issues/725)) ([a94caf0](https://github.com/ethpandaops/ethereum-package/commit/a94caf02c327347a7e6b4ed2f99badb787a25dc7))
* disable all assertoor tests by default ([#738](https://github.com/ethpandaops/ethereum-package/issues/738)) ([2961f96](https://github.com/ethpandaops/ethereum-package/commit/2961f969402b3f3dbf6f584e74644cf32cfd7902))
* lodestar vc faster startup ([#721](https://github.com/ethpandaops/ethereum-package/issues/721)) ([225e3d8](https://github.com/ethpandaops/ethereum-package/commit/225e3d80fe0389f6a22c88a56075ad86a1ae2b00))
* readme eof ([#739](https://github.com/ethpandaops/ethereum-package/issues/739)) ([7f94f6e](https://github.com/ethpandaops/ethereum-package/commit/7f94f6e2fefe21e11edb7cf5dc827e3f486afe98))
* remove custom peerdas images for dora & assertoor ([#741](https://github.com/ethpandaops/ethereum-package/issues/741)) ([a19398d](https://github.com/ethpandaops/ethereum-package/commit/a19398decc892ba6749284495891184de987cab0))
* remove subscribe all subnet nimbus ([#719](https://github.com/ethpandaops/ethereum-package/issues/719)) ([ef92f8f](https://github.com/ethpandaops/ethereum-package/commit/ef92f8f45e4e32d0e2b9711ca9671ff5d1bcab00))
* remove subscribe-all-subnets from default prysm config ([#717](https://github.com/ethpandaops/ethereum-package/issues/717)) ([6348c0b](https://github.com/ethpandaops/ethereum-package/commit/6348c0b4c0b8a03a27cdf8a5fa8615b0ab323d7b))
* remove subscribe-all-subnets lighthouse/lodestar/teku ([#720](https://github.com/ethpandaops/ethereum-package/issues/720)) ([cdb20e1](https://github.com/ethpandaops/ethereum-package/commit/cdb20e18110e3c85817adc7e970d4b4cbd445feb))
* update snapshots URL ([#731](https://github.com/ethpandaops/ethereum-package/issues/731)) ([f9269ad](https://github.com/ethpandaops/ethereum-package/commit/f9269ad7e7bc04fae486b340f8d189d3b965f4b2))

## [4.1.0](https://github.com/ethpandaops/ethereum-package/compare/4.0.0...4.1.0) (2024-07-03)


### Features

* add back k8s tests ([#699](https://github.com/ethpandaops/ethereum-package/issues/699)) ([d621cf0](https://github.com/ethpandaops/ethereum-package/commit/d621cf0a4936c40778e492bb307fef990477aa52))
* add checkpoint_enabled and checkpoint_url flags ([#689](https://github.com/ethpandaops/ethereum-package/issues/689)) ([b8cd2b4](https://github.com/ethpandaops/ethereum-package/commit/b8cd2b4574d4f8defa343532a7725b9ae3be692b))
* add eof support ([#682](https://github.com/ethpandaops/ethereum-package/issues/682)) ([cb203ff](https://github.com/ethpandaops/ethereum-package/commit/cb203ff1e9929529570f4dc59b7b3cb6022ff670))
* add mev relays to dora config ([#679](https://github.com/ethpandaops/ethereum-package/issues/679)) ([293001a](https://github.com/ethpandaops/ethereum-package/commit/293001a1e116e7e727d19ed42ba3e7113171f561))
* Add static ports ([#677](https://github.com/ethpandaops/ethereum-package/issues/677)) ([4f054d0](https://github.com/ethpandaops/ethereum-package/commit/4f054d0566c1a8a8f90a5436d022cd5fe36d7c3c))
* add ws_url to el_context ([#696](https://github.com/ethpandaops/ethereum-package/issues/696)) ([26fea61](https://github.com/ethpandaops/ethereum-package/commit/26fea619789253f73c1f53eb9478347bb908387a))
* introduce devnet_repo override ([#686](https://github.com/ethpandaops/ethereum-package/issues/686)) ([9952361](https://github.com/ethpandaops/ethereum-package/commit/99523611622dbbefc2a523e6b011e63487b1cbf7))
* use CDN URL for data snapshots used for shadow forks ([#676](https://github.com/ethpandaops/ethereum-package/issues/676)) ([91dc68c](https://github.com/ethpandaops/ethereum-package/commit/91dc68c9e709729e2a8c2fa59f48d8901eb49bb5))


### Bug Fixes

* besu bonsai log disable ([#673](https://github.com/ethpandaops/ethereum-package/issues/673)) ([955f19f](https://github.com/ethpandaops/ethereum-package/commit/955f19f8a79eda7d3d645c0c3d3a822705f10a7d))
* blockscout bad return ([#685](https://github.com/ethpandaops/ethereum-package/issues/685)) ([e80870b](https://github.com/ethpandaops/ethereum-package/commit/e80870b3f955d5e350e3b14ab8ea2e49fa8d2f48))
* bump peerdas images ([#678](https://github.com/ethpandaops/ethereum-package/issues/678)) ([1acc201](https://github.com/ethpandaops/ethereum-package/commit/1acc201cbb7314c593963e042796e4d93ceaf960))
* DNS-1035 label ([#697](https://github.com/ethpandaops/ethereum-package/issues/697)) ([440fb31](https://github.com/ethpandaops/ethereum-package/commit/440fb319084fc8ea16f961410162d35290deeb22))
* ephemery genesis loader ([#700](https://github.com/ethpandaops/ethereum-package/issues/700)) ([0235063](https://github.com/ethpandaops/ethereum-package/commit/023506362d489124d88f1d2b15408f08fbdd173e))
* ignore bootnodes if in shadowfork ([#660](https://github.com/ethpandaops/ethereum-package/issues/660)) ([cda5dda](https://github.com/ethpandaops/ethereum-package/commit/cda5ddac51e4ce2228f2a4da1d242b2fcb7eeccd))
* minimal eof ([#687](https://github.com/ethpandaops/ethereum-package/issues/687)) ([26a7618](https://github.com/ethpandaops/ethereum-package/commit/26a76187cd65114640764cc4eefc4a6c7517b57a))
* release please manifest ([#675](https://github.com/ethpandaops/ethereum-package/issues/675)) ([75ed7e1](https://github.com/ethpandaops/ethereum-package/commit/75ed7e18309d1d3884e222abcd097366649288cc))
* remove docker login ([#701](https://github.com/ethpandaops/ethereum-package/issues/701)) ([ede5962](https://github.com/ethpandaops/ethereum-package/commit/ede596266d2a0fe8af0e1bf21c6a09e4685b67a5))
* return empty services ([#688](https://github.com/ethpandaops/ethereum-package/issues/688)) ([6571a70](https://github.com/ethpandaops/ethereum-package/commit/6571a70bccb310957d531daea6685f641469b546))
* return the correct network_id ([#705](https://github.com/ethpandaops/ethereum-package/issues/705)) ([7c592f6](https://github.com/ethpandaops/ethereum-package/commit/7c592f6741718c20bdce4bd3bd6035b3ce37f38d))

## [4.0.0](https://github.com/ethpandaops/ethereum-package/compare/3.1.0...v4.0.0) (2024-06-13)


### ⚠ BREAKING CHANGES

* migrate from kurtosis-tech to ethpandaops repository ([#663](https://github.com/ethpandaops/ethereum-package/issues/663))

### Features

* add names to run-sh ([#666](https://github.com/ethpandaops/ethereum-package/issues/666)) ([6b447b7](https://github.com/ethpandaops/ethereum-package/commit/6b447b7254ce1e9d7a2383eb1a0b9435bbabf237))
* Adding arbitrary contract definition ([#646](https://github.com/ethpandaops/ethereum-package/issues/646)) ([cb58b65](https://github.com/ethpandaops/ethereum-package/commit/cb58b65911828b333c2aabf9052e30d79a8a55aa))
* migrate from kurtosis-tech to ethpandaops repository ([#663](https://github.com/ethpandaops/ethereum-package/issues/663)) ([d980fee](https://github.com/ethpandaops/ethereum-package/commit/d980feedac0fbe6a18a6b699f62d3f3275657b16))
* update Lodestar BN &lt;&gt; VC compatibility ([#664](https://github.com/ethpandaops/ethereum-package/issues/664)) ([7f365da](https://github.com/ethpandaops/ethereum-package/commit/7f365da6607bd863b12170ed475b77f4fafcc146))


### Bug Fixes

* permissions on autorelease ([#671](https://github.com/ethpandaops/ethereum-package/issues/671)) ([fcaa2c2](https://github.com/ethpandaops/ethereum-package/commit/fcaa2c23301c0f7012301fe019a75b0fa369961b))
* update release please ([#670](https://github.com/ethpandaops/ethereum-package/issues/670)) ([fa53672](https://github.com/ethpandaops/ethereum-package/commit/fa536729886fa911ce4778b6d4097e2fb69a6c06))

## [3.1.0](https://github.com/kurtosis-tech/ethereum-package/compare/3.0.0...3.1.0) (2024-06-07)


### Features

* add http url to el context ([#656](https://github.com/kurtosis-tech/ethereum-package/issues/656)) ([4e69a4c](https://github.com/kurtosis-tech/ethereum-package/commit/4e69a4c057c600d479879691837ba2ef7f683a34))
* add prefunded accounts to output ([#657](https://github.com/kurtosis-tech/ethereum-package/issues/657)) ([bc06e2a](https://github.com/kurtosis-tech/ethereum-package/commit/bc06e2a4e93add97c75c5b520b87a6b9863a9faf))
* add tracoor ([#651](https://github.com/kurtosis-tech/ethereum-package/issues/651)) ([b100cb6](https://github.com/kurtosis-tech/ethereum-package/commit/b100cb6fac5646783c0ee580ec3425fd74e0e4a1))
* add vc_count to increase the number of validators per participant ([#633](https://github.com/kurtosis-tech/ethereum-package/issues/633)) ([4272ff3](https://github.com/kurtosis-tech/ethereum-package/commit/4272ff3e27be1c85fd5e8e606b956ea31c0ae3b9))
* allow setting custom dora image & env variables ([#623](https://github.com/kurtosis-tech/ethereum-package/issues/623)) ([08a65c3](https://github.com/kurtosis-tech/ethereum-package/commit/08a65c33b645a1dc656feb0671513d9bf1b84c66))
* **apache:** Serve all config files ([#606](https://github.com/kurtosis-tech/ethereum-package/issues/606)) ([3f1f5e1](https://github.com/kurtosis-tech/ethereum-package/commit/3f1f5e118e5d125ec108a40f0edc0b0617a60b5f))
* **config:** add peerdas vars ([#619](https://github.com/kurtosis-tech/ethereum-package/issues/619)) ([22f1498](https://github.com/kurtosis-tech/ethereum-package/commit/22f1498a3d344150827a2393df3e3ff0c693a6ff))
* expose network-params ([#659](https://github.com/kurtosis-tech/ethereum-package/issues/659)) ([b0820dd](https://github.com/kurtosis-tech/ethereum-package/commit/b0820ddae77e7d45d090c00e47aa3e8d3832e194))
* forky ([#625](https://github.com/kurtosis-tech/ethereum-package/issues/625)) ([ded68bd](https://github.com/kurtosis-tech/ethereum-package/commit/ded68bdc73dbb0e166ef8e02dc3ab577066d0214))
* Support participants_matrix ([#620](https://github.com/kurtosis-tech/ethereum-package/issues/620)) ([3a57467](https://github.com/kurtosis-tech/ethereum-package/commit/3a57467519ca20a519985ce2e2257c3694dc4fde))
* use `peer-das` image for dora when eip7594 is active ([#593](https://github.com/kurtosis-tech/ethereum-package/issues/593)) ([1b4bd3d](https://github.com/kurtosis-tech/ethereum-package/commit/1b4bd3d1478839474a26d163312e99a810399b1b))


### Bug Fixes

* add additional prefund addresses ([#655](https://github.com/kurtosis-tech/ethereum-package/issues/655)) ([6d2cdb6](https://github.com/kurtosis-tech/ethereum-package/commit/6d2cdb6982da76f95bdde2b7930fbea9117016b8))
* add cl log level to builders ([#638](https://github.com/kurtosis-tech/ethereum-package/issues/638)) ([ad46dbd](https://github.com/kurtosis-tech/ethereum-package/commit/ad46dbdf8babbc5bf6a5aae9ee9ee4be54491a92))
* Add EIP-7002 & EIP-2935 bytecode to ethereum-genesis-generator ([#597](https://github.com/kurtosis-tech/ethereum-package/issues/597)) ([3d316ef](https://github.com/kurtosis-tech/ethereum-package/commit/3d316ef631b038355b88d23024d19086699bd452))
* add http to teku endpoint ([#622](https://github.com/kurtosis-tech/ethereum-package/issues/622)) ([085b6e1](https://github.com/kurtosis-tech/ethereum-package/commit/085b6e126fc0ccf98431d74f56e9965fa8b1f665))
* add peer_das_epoch to egg ([#603](https://github.com/kurtosis-tech/ethereum-package/issues/603)) ([91694df](https://github.com/kurtosis-tech/ethereum-package/commit/91694dfc1e8b64ac76b7dfda006f19db358941fa))
* add sha256 as an image label (if present) ([#637](https://github.com/kurtosis-tech/ethereum-package/issues/637)) ([3dcf888](https://github.com/kurtosis-tech/ethereum-package/commit/3dcf888326266aaba38f8253e47b3dd85a457cd0))
* add static port config for apache ([#608](https://github.com/kurtosis-tech/ethereum-package/issues/608)) ([b96e502](https://github.com/kurtosis-tech/ethereum-package/commit/b96e502145010694579d7b938a8112e0311ecb8b))
* **apache:** only set static port if wanted ([#610](https://github.com/kurtosis-tech/ethereum-package/issues/610)) ([2c6b7b1](https://github.com/kurtosis-tech/ethereum-package/commit/2c6b7b1af7b7513adf46394b9138f726a57f9e38))
* blockscout fix for json variant ([#662](https://github.com/kurtosis-tech/ethereum-package/issues/662)) ([e79c510](https://github.com/kurtosis-tech/ethereum-package/commit/e79c5101f44ca3a5bd70f16b2cf24976db8e555e))
* churn adjustments ([#614](https://github.com/kurtosis-tech/ethereum-package/issues/614)) ([12ca872](https://github.com/kurtosis-tech/ethereum-package/commit/12ca8721b42e000bcf8b6624a0b3c7b6cbde57bd))
* default config ([#632](https://github.com/kurtosis-tech/ethereum-package/issues/632)) ([14be117](https://github.com/kurtosis-tech/ethereum-package/commit/14be117598bca0d733cb8b1dc439abdde5be8ae1))
* drop everythign after [@sha](https://github.com/sha) from image labels ([#636](https://github.com/kurtosis-tech/ethereum-package/issues/636)) ([5d35463](https://github.com/kurtosis-tech/ethereum-package/commit/5d35463853b6bb7e58112b5df246660c8d1bd02d))
* erigon v3 - new default image ([#629](https://github.com/kurtosis-tech/ethereum-package/issues/629)) ([72cf150](https://github.com/kurtosis-tech/ethereum-package/commit/72cf150c580addc00c1ca0693b568d62b06118a1))
* genesis generator bump ([#611](https://github.com/kurtosis-tech/ethereum-package/issues/611)) ([5460f6f](https://github.com/kurtosis-tech/ethereum-package/commit/5460f6fc26972fe576ef89d521d5251470e65b5e))
* nightly tests ([#595](https://github.com/kurtosis-tech/ethereum-package/issues/595)) ([76c31e9](https://github.com/kurtosis-tech/ethereum-package/commit/76c31e91d830490c956321cc2f6b3301a8d6fd27))
* pectra example ([#605](https://github.com/kurtosis-tech/ethereum-package/issues/605)) ([67e3da0](https://github.com/kurtosis-tech/ethereum-package/commit/67e3da0e0cf4314353d5cea806186530df54a1cd))
* prysm vc key manager ports ([#639](https://github.com/kurtosis-tech/ethereum-package/issues/639)) ([81c1ee7](https://github.com/kurtosis-tech/ethereum-package/commit/81c1ee70a56f910ecd6b710dd0fe3721d81b6dcf))
* re-add images to labels ([#634](https://github.com/kurtosis-tech/ethereum-package/issues/634)) ([71f6e28](https://github.com/kurtosis-tech/ethereum-package/commit/71f6e28e682e47a550ffef037c7b26ce836d96df))
* README has invalid configs ([#631](https://github.com/kurtosis-tech/ethereum-package/issues/631)) ([e33b971](https://github.com/kurtosis-tech/ethereum-package/commit/e33b97171f1aedb647191e3b02835a8004cbaade))
* readme indentation ([#600](https://github.com/kurtosis-tech/ethereum-package/issues/600)) ([583db1b](https://github.com/kurtosis-tech/ethereum-package/commit/583db1b4ebaa5ab2e5eb2f97aa7414f89376b022))
* registration flags when using beacon node only ([#618](https://github.com/kurtosis-tech/ethereum-package/issues/618)) ([c12506b](https://github.com/kurtosis-tech/ethereum-package/commit/c12506b9587c9a87e89d2938351d72c4676160e1))
* repair check workflow for external PRs ([#616](https://github.com/kurtosis-tech/ethereum-package/issues/616)) ([a584682](https://github.com/kurtosis-tech/ethereum-package/commit/a5846821563d318b993de48baab5e3a9c9e267d0))
* seperate vc service names ([#654](https://github.com/kurtosis-tech/ethereum-package/issues/654)) ([a5ffe14](https://github.com/kurtosis-tech/ethereum-package/commit/a5ffe14e7d3c9f7ec6dbebd79a4b42c24394c0f7))
* tune Besu options to work with tx_spammer ([#612](https://github.com/kurtosis-tech/ethereum-package/issues/612)) ([b395189](https://github.com/kurtosis-tech/ethereum-package/commit/b39518904fbf2cad5ca2ec18ce1bc18455207014))
* update dora images ([#598](https://github.com/kurtosis-tech/ethereum-package/issues/598)) ([dd28d61](https://github.com/kurtosis-tech/ethereum-package/commit/dd28d61a31bdc4c58c33ca733487535041f5ae0a))
* update prysm image ([#599](https://github.com/kurtosis-tech/ethereum-package/issues/599)) ([0a38114](https://github.com/kurtosis-tech/ethereum-package/commit/0a38114e8444837d7cff9aab9afe6b06e1c99d84))
* use `electra-support` image for assertoor when electra fork epoch is set ([#607](https://github.com/kurtosis-tech/ethereum-package/issues/607)) ([cdeab93](https://github.com/kurtosis-tech/ethereum-package/commit/cdeab939eda037770b89b580658a87817aac1158))

## [3.0.0](https://github.com/kurtosis-tech/ethereum-package/compare/2.2.0...3.0.0) (2024-05-06)


### ⚠ BREAKING CHANGES

* add mev-rs relay/builder/boost ([#586](https://github.com/kurtosis-tech/ethereum-package/issues/586))
* upcoming file path change in kurtosis upstream ([#582](https://github.com/kurtosis-tech/ethereum-package/issues/582))

### Features

* add apache file server ([#581](https://github.com/kurtosis-tech/ethereum-package/issues/581)) ([205256a](https://github.com/kurtosis-tech/ethereum-package/commit/205256a6d79303719973655b459e803d9b8e311f))
* add enr/enode to apache ([#589](https://github.com/kurtosis-tech/ethereum-package/issues/589)) ([b789e17](https://github.com/kurtosis-tech/ethereum-package/commit/b789e1705f076ec6aa01ceffbf5fbeebb02d8c0f))
* add execution client urls to dora config ([#588](https://github.com/kurtosis-tech/ethereum-package/issues/588)) ([2a20d5a](https://github.com/kurtosis-tech/ethereum-package/commit/2a20d5ad7d2bf8f9a9eb2b619681b438810176d2))
* add mev-rs relay/builder/boost ([#586](https://github.com/kurtosis-tech/ethereum-package/issues/586)) ([525a8fb](https://github.com/kurtosis-tech/ethereum-package/commit/525a8fb3d794f8030a574f55f3a7e719c1b58dca))
* Add peerdas support ([#591](https://github.com/kurtosis-tech/ethereum-package/issues/591)) ([14296ca](https://github.com/kurtosis-tech/ethereum-package/commit/14296cab11d8c7a9572cf57a37980e1d93285cad))
* add snooper urls to assertoor config ([#571](https://github.com/kurtosis-tech/ethereum-package/issues/571)) ([87f383f](https://github.com/kurtosis-tech/ethereum-package/commit/87f383fbc7f9e28d383853fcb7cd491abe13a0cc))
* allow setting exit ip address ([#584](https://github.com/kurtosis-tech/ethereum-package/issues/584)) ([aabc942](https://github.com/kurtosis-tech/ethereum-package/commit/aabc942c4e8534288f28cdbb1e9e55f2613f383c))


### Bug Fixes

* non-existent field access on error message ([#577](https://github.com/kurtosis-tech/ethereum-package/issues/577)) ([8515d27](https://github.com/kurtosis-tech/ethereum-package/commit/8515d276056a47f9e6a77dd498f823042bff1a8f))
* participant redefining global flag ([#573](https://github.com/kurtosis-tech/ethereum-package/issues/573)) ([9139f4b](https://github.com/kurtosis-tech/ethereum-package/commit/9139f4b4c77bc43477740972512171d7f28bfa84))
* path for shadowforks post kt update ([#585](https://github.com/kurtosis-tech/ethereum-package/issues/585)) ([e0622a7](https://github.com/kurtosis-tech/ethereum-package/commit/e0622a77305732e01ee0fce183fda15c3dcd2dad))
* remove erigon's --chain parameter ([#575](https://github.com/kurtosis-tech/ethereum-package/issues/575)) ([02b9c50](https://github.com/kurtosis-tech/ethereum-package/commit/02b9c50495f9b8cce0b0df502f19b37c0cb21ffd))
* upcoming file path change in kurtosis upstream ([#582](https://github.com/kurtosis-tech/ethereum-package/issues/582)) ([8d7c4f9](https://github.com/kurtosis-tech/ethereum-package/commit/8d7c4f9c1feba07511c22d006b5121b45893f642))

## [2.2.0](https://github.com/kurtosis-tech/ethereum-package/compare/2.1.0...2.2.0) (2024-04-19)


### Features

* add assertoor test for per PR CI job ([#537](https://github.com/kurtosis-tech/ethereum-package/issues/537)) ([8ef5c57](https://github.com/kurtosis-tech/ethereum-package/commit/8ef5c57fc00b1e5ea9d59011fa61d771b1af5133))
* add blutgang rpc load balancer ([#569](https://github.com/kurtosis-tech/ethereum-package/issues/569)) ([1be5f95](https://github.com/kurtosis-tech/ethereum-package/commit/1be5f9542cf43b7b5afc3f565358b50dfbb81d50))
* add dugtrio beacon load balancer ([#568](https://github.com/kurtosis-tech/ethereum-package/issues/568)) ([56d2fa3](https://github.com/kurtosis-tech/ethereum-package/commit/56d2fa38e59018fa331c12a271a906ec4fe67e6e))
* add new assertoor test to per ci jobs ([#545](https://github.com/kurtosis-tech/ethereum-package/issues/545)) ([3005d46](https://github.com/kurtosis-tech/ethereum-package/commit/3005d46d60970be18e66f6a7f590d0b4689e84f4))
* use new rpc snooper from `ethpandaops/rpc-snooper` ([#567](https://github.com/kurtosis-tech/ethereum-package/issues/567)) ([5676f0d](https://github.com/kurtosis-tech/ethereum-package/commit/5676f0dd4d62ee25a7f8ca2959596e419743916d))


### Bug Fixes

* add --contract-deployment-block parameter for Prysm ([#557](https://github.com/kurtosis-tech/ethereum-package/issues/557)) ([d8dfbae](https://github.com/kurtosis-tech/ethereum-package/commit/d8dfbae531c038e3985cb15ca6bcbcf37f6526a0))
* Added '--enable-private-discovery' to Grandine ([#541](https://github.com/kurtosis-tech/ethereum-package/issues/541)) ([a1ae708](https://github.com/kurtosis-tech/ethereum-package/commit/a1ae708183873dec97e91986d6104c8dedc92100))
* beaconchain explorer ([#531](https://github.com/kurtosis-tech/ethereum-package/issues/531)) ([b62ed6f](https://github.com/kurtosis-tech/ethereum-package/commit/b62ed6f129c65b62f084ea2a78fab0fa80afd9e2))
* beaconchain explorer ([#538](https://github.com/kurtosis-tech/ethereum-package/issues/538)) ([ce1f337](https://github.com/kurtosis-tech/ethereum-package/commit/ce1f3373000d552a9b4b8b09ad5754ab092a61cb))
* blobber incorrect url ([#528](https://github.com/kurtosis-tech/ethereum-package/issues/528)) ([6f84e3d](https://github.com/kurtosis-tech/ethereum-package/commit/6f84e3d5ec5fd7c02016530b3b64c79114d5891e))
* bump json rpc snooper ([#553](https://github.com/kurtosis-tech/ethereum-package/issues/553)) ([f69c4a7](https://github.com/kurtosis-tech/ethereum-package/commit/f69c4a7468f97a4aa3aaea64dd18a63e561a6704))
* disable full sync if gcmode is archive ([#563](https://github.com/kurtosis-tech/ethereum-package/issues/563)) ([b7592ec](https://github.com/kurtosis-tech/ethereum-package/commit/b7592ecac5ca8820aa6de6fc5ae9bb9c0dc27c20))
* disable pbss when gcmode archive set ([#559](https://github.com/kurtosis-tech/ethereum-package/issues/559)) ([e085462](https://github.com/kurtosis-tech/ethereum-package/commit/e0854624ef69a069bb7ba482694cb83180df0680))
* disable pbss when gcmode archive set, force hash based init ([#562](https://github.com/kurtosis-tech/ethereum-package/issues/562)) ([3e1c7a6](https://github.com/kurtosis-tech/ethereum-package/commit/3e1c7a6585a50398e5750f6e37cf3d0685d35536))
* disable static peers ([#529](https://github.com/kurtosis-tech/ethereum-package/issues/529)) ([c5d4028](https://github.com/kurtosis-tech/ethereum-package/commit/c5d4028939691b887b928b91532f8139478ee4d2))
* enable single node mode on lodestar by default ([#558](https://github.com/kurtosis-tech/ethereum-package/issues/558)) ([555ad7d](https://github.com/kurtosis-tech/ethereum-package/commit/555ad7dc5180cc7f47e14baa3438879e6d4779e9))
* fix doc string typo ([#560](https://github.com/kurtosis-tech/ethereum-package/issues/560)) ([13de3f6](https://github.com/kurtosis-tech/ethereum-package/commit/13de3f68706a80088b28fbfefc69d738e06d13ef))
* fix failing persistence test ([#554](https://github.com/kurtosis-tech/ethereum-package/issues/554)) ([99242d6](https://github.com/kurtosis-tech/ethereum-package/commit/99242d66f3e0254684b75bce14353a854e735721))
* increase mem limit of snooper ([#546](https://github.com/kurtosis-tech/ethereum-package/issues/546)) ([6ba5770](https://github.com/kurtosis-tech/ethereum-package/commit/6ba577006e6f6eb0b477619399edb232f4ed9783))
* prysm beacon http url  ([#536](https://github.com/kurtosis-tech/ethereum-package/issues/536)) ([4914531](https://github.com/kurtosis-tech/ethereum-package/commit/4914531690eae32ba274e10ee7fa0ecf6d82ac68))
* prysm beacon_http_url ([#535](https://github.com/kurtosis-tech/ethereum-package/issues/535)) ([ee7528c](https://github.com/kurtosis-tech/ethereum-package/commit/ee7528c5d5872768e7ddc25e9da963e764e3b594))
* prysm vc ([#533](https://github.com/kurtosis-tech/ethereum-package/issues/533)) ([72ddeb2](https://github.com/kurtosis-tech/ethereum-package/commit/72ddeb25c1bb0a8132c1a3a73bd8f7764cb01659))
* remove un-needed prysm vc check ([#542](https://github.com/kurtosis-tech/ethereum-package/issues/542)) ([f6326fe](https://github.com/kurtosis-tech/ethereum-package/commit/f6326fe2119648478ab1bfc90220cbd4b4e12cac))
* set application protocol to be http for rpc ([#548](https://github.com/kurtosis-tech/ethereum-package/issues/548)) ([905de7c](https://github.com/kurtosis-tech/ethereum-package/commit/905de7c3635c3c057f67ae6589d708d9dc6d5ddd))
* set the correct default vc image ([#544](https://github.com/kurtosis-tech/ethereum-package/issues/544)) ([953741d](https://github.com/kurtosis-tech/ethereum-package/commit/953741d824a4a76a1194c2643012bf738669c3ad))
* uniformize keymanager ([#534](https://github.com/kurtosis-tech/ethereum-package/issues/534)) ([a6a2830](https://github.com/kurtosis-tech/ethereum-package/commit/a6a2830e90919999c6c391e9aa832094cf440d35))
* update prometheus api ([#539](https://github.com/kurtosis-tech/ethereum-package/issues/539)) ([d2b9fb8](https://github.com/kurtosis-tech/ethereum-package/commit/d2b9fb8961eac8a712af36f49ac8a1f918dabb6b))
* update vc &lt;&gt; cl matrix ([#564](https://github.com/kurtosis-tech/ethereum-package/issues/564)) ([0ffcf74](https://github.com/kurtosis-tech/ethereum-package/commit/0ffcf74cf3a83b0c462bc26d07254160b132b27a))
* update vc compatibility matrix ([#543](https://github.com/kurtosis-tech/ethereum-package/issues/543)) ([58c4684](https://github.com/kurtosis-tech/ethereum-package/commit/58c4684594711ee58bf117c31d5cf688d476892e))
* use `minimal-preset` images for dora & assertoor when minimal preset is used ([#532](https://github.com/kurtosis-tech/ethereum-package/issues/532)) ([ad7773e](https://github.com/kurtosis-tech/ethereum-package/commit/ad7773e86f1e1bb1f48b96e5126231fd060822e8))

## [2.1.0](https://github.com/kurtosis-tech/ethereum-package/compare/2.0.0...2.1.0) (2024-03-28)


### Features

* add beacon snooper ([#520](https://github.com/kurtosis-tech/ethereum-package/issues/520)) ([7e36191](https://github.com/kurtosis-tech/ethereum-package/commit/7e361913c754ddf37eaf2cf3ad4a93aed8770899))
* add BN&lt;&gt;CL compatibility matrix to readme ([#519](https://github.com/kurtosis-tech/ethereum-package/issues/519)) ([177beeb](https://github.com/kurtosis-tech/ethereum-package/commit/177beeb9b46f61b3dd3dc3009ff2abf9b576c569))
* add grandine ([#517](https://github.com/kurtosis-tech/ethereum-package/issues/517)) ([3ac4d2a](https://github.com/kurtosis-tech/ethereum-package/commit/3ac4d2a4fae1c33ff658f0f43657a09522348127))
* enable preset to be set, mainnet/minimal ([#524](https://github.com/kurtosis-tech/ethereum-package/issues/524)) ([f6e1b13](https://github.com/kurtosis-tech/ethereum-package/commit/f6e1b136ef6b884e540c1289b8acc2b4d359e6ce))
* make deneb genesis default ([#518](https://github.com/kurtosis-tech/ethereum-package/issues/518)) ([49509b9](https://github.com/kurtosis-tech/ethereum-package/commit/49509b9ecb8b00d361e4119ee053ba86c366619e))
* make keymanager optional ([#523](https://github.com/kurtosis-tech/ethereum-package/issues/523)) ([969012c](https://github.com/kurtosis-tech/ethereum-package/commit/969012c3b504be1c475bd583675857d0605ed430))
* update verkle genesis + add besu support to verkle testing  ([#512](https://github.com/kurtosis-tech/ethereum-package/issues/512)) ([0615cd1](https://github.com/kurtosis-tech/ethereum-package/commit/0615cd1b4466d8f63e3adb721d97ee768211114f))


### Bug Fixes

* architecture.md ([#514](https://github.com/kurtosis-tech/ethereum-package/issues/514)) ([f0ec4f0](https://github.com/kurtosis-tech/ethereum-package/commit/f0ec4f076837b282a8972bd2211a0522ed67a06b))
* blobscan network name ([#516](https://github.com/kurtosis-tech/ethereum-package/issues/516)) ([83c2a55](https://github.com/kurtosis-tech/ethereum-package/commit/83c2a5592445c0efc10ab418d87ab2ecd4d10cf4))
* **blobscan:** update healthcheck endpoint ([#513](https://github.com/kurtosis-tech/ethereum-package/issues/513)) ([8b2fc61](https://github.com/kurtosis-tech/ethereum-package/commit/8b2fc61f77b53642441d3bd0bdeea89b2a2d35eb))
* separate vc ([#526](https://github.com/kurtosis-tech/ethereum-package/issues/526)) ([baa04e9](https://github.com/kurtosis-tech/ethereum-package/commit/baa04e9118f39b10ed7d867eec164483c6fd807d))
* Updated Readme with VCs supported by Grandine BN ([#527](https://github.com/kurtosis-tech/ethereum-package/issues/527)) ([9cbe0b3](https://github.com/kurtosis-tech/ethereum-package/commit/9cbe0b368205f70ee274d9c0c57f634f9621e6d7))
* use correct dora & assertoor images ([#522](https://github.com/kurtosis-tech/ethereum-package/issues/522)) ([2a8d73a](https://github.com/kurtosis-tech/ethereum-package/commit/2a8d73aba35bf26bfcd474036bac32c4f5713e35))
* use new validator names in assertoor config ([#521](https://github.com/kurtosis-tech/ethereum-package/issues/521)) ([f595eb9](https://github.com/kurtosis-tech/ethereum-package/commit/f595eb9a75e8c2147d530d1a70e6ccb9f3542257))

## [2.0.0](https://github.com/kurtosis-tech/ethereum-package/compare/1.4.0...2.0.0) (2024-03-08)


### ⚠ BREAKING CHANGES

* participant_network & rename participant fields. ([#508](https://github.com/kurtosis-tech/ethereum-package/issues/508))
* add node selectors features ([#491](https://github.com/kurtosis-tech/ethereum-package/issues/491))

### Features

* add keymanager to all validator processes ([#502](https://github.com/kurtosis-tech/ethereum-package/issues/502)) ([836eda4](https://github.com/kurtosis-tech/ethereum-package/commit/836eda4eed3776dd406d354343655c0ff8b9d2b6))
* add nimbus-eth1 ([#496](https://github.com/kurtosis-tech/ethereum-package/issues/496)) ([d599729](https://github.com/kurtosis-tech/ethereum-package/commit/d599729295aa3274d23e4e8e99b56288cde3fc04))
* add node selectors features ([#491](https://github.com/kurtosis-tech/ethereum-package/issues/491)) ([316d42f](https://github.com/kurtosis-tech/ethereum-package/commit/316d42fbaeb2d7bc1d580823a6c70b1c2dfe3746))
* allow more detailed additional test configurations in assertoor_params ([#498](https://github.com/kurtosis-tech/ethereum-package/issues/498)) ([fe2de7e](https://github.com/kurtosis-tech/ethereum-package/commit/fe2de7e5a5e2446ebb0a0b191f5aa6783e132426))
* enable api in assertoor config ([#495](https://github.com/kurtosis-tech/ethereum-package/issues/495)) ([9ceae9c](https://github.com/kurtosis-tech/ethereum-package/commit/9ceae9c74405db4e1ab6e02de541577d078434ae))
* enable dencun-genesis ([#500](https://github.com/kurtosis-tech/ethereum-package/issues/500)) ([beb764f](https://github.com/kurtosis-tech/ethereum-package/commit/beb764fb9a18fcb09cb7d3d9ee48e4826595512d))
* make snapshot url configurable ([#507](https://github.com/kurtosis-tech/ethereum-package/issues/507)) ([6fa0475](https://github.com/kurtosis-tech/ethereum-package/commit/6fa04751cd1277a4870dc45144e15ffa5d637b93))
* parameterize mev-boost args ([#400](https://github.com/kurtosis-tech/ethereum-package/issues/400)) ([e48483a](https://github.com/kurtosis-tech/ethereum-package/commit/e48483a130ba227dafd0d0fd9ee66c6cecc3bfce))
* separate validator clients from CL clients ([#497](https://github.com/kurtosis-tech/ethereum-package/issues/497)) ([90da2c3](https://github.com/kurtosis-tech/ethereum-package/commit/90da2c33a77b4a0ac620ae665899963256a1ae0a))


### Bug Fixes

* fix end index in validator ranges file ([#509](https://github.com/kurtosis-tech/ethereum-package/issues/509)) ([da55be8](https://github.com/kurtosis-tech/ethereum-package/commit/da55be84861e93ce777076e545abee35ff2d51ce))
* lh vc flag logic ([#506](https://github.com/kurtosis-tech/ethereum-package/issues/506)) ([bc5e725](https://github.com/kurtosis-tech/ethereum-package/commit/bc5e725edf8c917d409e6de6ce838797ad166173))
* nimbus-eth1 advertise proper extip ([#501](https://github.com/kurtosis-tech/ethereum-package/issues/501)) ([1d5a779](https://github.com/kurtosis-tech/ethereum-package/commit/1d5a7792c8175d1fc85e424b5ddf60baec551821))
* README global node selector ([#504](https://github.com/kurtosis-tech/ethereum-package/issues/504)) ([f9343a2](https://github.com/kurtosis-tech/ethereum-package/commit/f9343a2914456196e1209336c426b6ad44958428))
* use the cl as the default validator image if none are defined ([#503](https://github.com/kurtosis-tech/ethereum-package/issues/503)) ([181dd04](https://github.com/kurtosis-tech/ethereum-package/commit/181dd04c2db17c58cb9370b0d24e12e4c191a13d))


### Code Refactoring

* participant_network & rename participant fields. ([#508](https://github.com/kurtosis-tech/ethereum-package/issues/508)) ([fab341b](https://github.com/kurtosis-tech/ethereum-package/commit/fab341b158329b9e8c2b590dc63127dfd1d2495f))

## [1.4.0](https://github.com/kurtosis-tech/ethereum-package/compare/1.3.0...1.4.0) (2024-02-09)


### Features

* Add suave-enabled geth support ([#489](https://github.com/kurtosis-tech/ethereum-package/issues/489)) ([631eaf3](https://github.com/kurtosis-tech/ethereum-package/commit/631eaf3e621c90d5b546a1c005d8e31e06263aa4))
* add support for custom assertoor images & use assertoor image with verkle support for verkle chains ([#483](https://github.com/kurtosis-tech/ethereum-package/issues/483)) ([2d8a143](https://github.com/kurtosis-tech/ethereum-package/commit/2d8a143f753eaa3ec13abe4ebbb57bf82548b3fb))
* add verkle-gen-devnet-3 ([#487](https://github.com/kurtosis-tech/ethereum-package/issues/487)) ([1e543e8](https://github.com/kurtosis-tech/ethereum-package/commit/1e543e873c06e86a6448f8e88c53fb1bde35338e))
* blockscout support with sc verification ([#481](https://github.com/kurtosis-tech/ethereum-package/issues/481)) ([b3418cf](https://github.com/kurtosis-tech/ethereum-package/commit/b3418cf1545378d4b412966b9c33f650141aec04))
* enable custom resource limit per network ([#471](https://github.com/kurtosis-tech/ethereum-package/issues/471)) ([5db6611](https://github.com/kurtosis-tech/ethereum-package/commit/5db6611ab831a92212a21859b42a911cd12bce0c))
* enable shadowforking ([#475](https://github.com/kurtosis-tech/ethereum-package/issues/475)) ([b788b18](https://github.com/kurtosis-tech/ethereum-package/commit/b788b18eead00622ab960a4853c8e24b09c16a26))
* improve built-in assertoor tests ([#488](https://github.com/kurtosis-tech/ethereum-package/issues/488)) ([d596699](https://github.com/kurtosis-tech/ethereum-package/commit/d5966991653ad48094cf71d3c01612349a651877))
* we no longer need 4788 deployer ([#485](https://github.com/kurtosis-tech/ethereum-package/issues/485)) ([abdfc2c](https://github.com/kurtosis-tech/ethereum-package/commit/abdfc2c3e73550069c2fbe0df5202f7f227a00cd))


### Bug Fixes

* add more prefund addresses for verkle-gen ([#482](https://github.com/kurtosis-tech/ethereum-package/issues/482)) ([01868fc](https://github.com/kurtosis-tech/ethereum-package/commit/01868fcb604852cf66474fc9de9a53a7b87b7bc3))
* bump verkle genesis generator ([#486](https://github.com/kurtosis-tech/ethereum-package/issues/486)) ([79dc5e1](https://github.com/kurtosis-tech/ethereum-package/commit/79dc5e19713d3f898f6255394290497d016f32d5))
* use latest stable image for assertoor ([#484](https://github.com/kurtosis-tech/ethereum-package/issues/484)) ([bbe0b16](https://github.com/kurtosis-tech/ethereum-package/commit/bbe0b16e948fc50f51273e2f0ab91503603e9fc9))

## [1.3.0](https://github.com/kurtosis-tech/ethereum-package/compare/1.2.0...1.3.0) (2024-01-22)


### Features

* add assertoor to additional toolings ([#419](https://github.com/kurtosis-tech/ethereum-package/issues/419)) ([76dde3e](https://github.com/kurtosis-tech/ethereum-package/commit/76dde3ed421da0d7f8ba16f46565b07019be76c0))
* add devnets support ([#384](https://github.com/kurtosis-tech/ethereum-package/issues/384)) ([2bae099](https://github.com/kurtosis-tech/ethereum-package/commit/2bae09931ed1cdcfe499efaae420c981dabcea62))
* add pitfalls for persistent storage as a warning ([#441](https://github.com/kurtosis-tech/ethereum-package/issues/441)) ([69da8f0](https://github.com/kurtosis-tech/ethereum-package/commit/69da8f04fcfd5ce19365bd89ca73c13cbc40d76a))
* add support for testnets ([#437](https://github.com/kurtosis-tech/ethereum-package/issues/437)) ([5584cc8](https://github.com/kurtosis-tech/ethereum-package/commit/5584cc84c50ca9845c544810fb8331ec8fcdcbc8))
* Add Xatu Sentry ([#466](https://github.com/kurtosis-tech/ethereum-package/issues/466)) ([b9523cb](https://github.com/kurtosis-tech/ethereum-package/commit/b9523cb7083be78c96bb88a7ca86d142cb0eec1d))
* enable checkpoint sync for devnets ([#448](https://github.com/kurtosis-tech/ethereum-package/issues/448)) ([b367cfe](https://github.com/kurtosis-tech/ethereum-package/commit/b367cfe875900bdc8aa70dc8b1d8aebdbcf81593))
* enable persistence ([#422](https://github.com/kurtosis-tech/ethereum-package/issues/422)) ([8d40056](https://github.com/kurtosis-tech/ethereum-package/commit/8d400566aa54132dccaa7ff129adc12e547907a0))
* enable syncing ephemery ([#459](https://github.com/kurtosis-tech/ethereum-package/issues/459)) ([f8289cb](https://github.com/kurtosis-tech/ethereum-package/commit/f8289cb49f68dd488635d2313c007ee7c2f4dbf3))
* enable syncing shadowforks ([#457](https://github.com/kurtosis-tech/ethereum-package/issues/457)) ([313a586](https://github.com/kurtosis-tech/ethereum-package/commit/313a586965efa6739e8d4055f1263a89d48ff499))


### Bug Fixes

* add CL genesis delay to final genesis time ([#469](https://github.com/kurtosis-tech/ethereum-package/issues/469)) ([e36027b](https://github.com/kurtosis-tech/ethereum-package/commit/e36027b91de0ae8943012ffd6ba776142d2e2d78))
* add prysm-multiarch upstream image ([#451](https://github.com/kurtosis-tech/ethereum-package/issues/451)) ([6feba23](https://github.com/kurtosis-tech/ethereum-package/commit/6feba237fbdfae021402ceeec89baa75df6d83d5))
* added supprot for boot enr file ([#456](https://github.com/kurtosis-tech/ethereum-package/issues/456)) ([fd26e5c](https://github.com/kurtosis-tech/ethereum-package/commit/fd26e5c31609b48e1d6718f72d295a27a7d84a49))
* bump max mem limit for nimbus on holesky ([#439](https://github.com/kurtosis-tech/ethereum-package/issues/439)) ([fb84787](https://github.com/kurtosis-tech/ethereum-package/commit/fb84787694faa86872828b92529f51e6c9ac7d44))
* dora template fix ([#452](https://github.com/kurtosis-tech/ethereum-package/issues/452)) ([f9243ea](https://github.com/kurtosis-tech/ethereum-package/commit/f9243ea8cdec8a0145206831c9c043269c80e863))
* enable ws for geth ([#446](https://github.com/kurtosis-tech/ethereum-package/issues/446)) ([d5bf451](https://github.com/kurtosis-tech/ethereum-package/commit/d5bf45150dc09432bb84b366d2deda8c6036afea))
* erigon chain should be set to dev ([#447](https://github.com/kurtosis-tech/ethereum-package/issues/447)) ([1f40d84](https://github.com/kurtosis-tech/ethereum-package/commit/1f40d8402666310cad81066852110aa20627471b))
* erigon command arg ([#454](https://github.com/kurtosis-tech/ethereum-package/issues/454)) ([5ae56a1](https://github.com/kurtosis-tech/ethereum-package/commit/5ae56a17773122827b074963dee40a43a00478ea))
* fix typo ([#440](https://github.com/kurtosis-tech/ethereum-package/issues/440)) ([933a313](https://github.com/kurtosis-tech/ethereum-package/commit/933a3133bf9b1fe96ea3c537b26c3c8ced0a35e3))
* guid fix for besu/teku/erigon/nimbus ([#443](https://github.com/kurtosis-tech/ethereum-package/issues/443)) ([2283464](https://github.com/kurtosis-tech/ethereum-package/commit/2283464b614b0ade4aa98fccd842e8e4b23e188a))
* increase db size for geth ([#453](https://github.com/kurtosis-tech/ethereum-package/issues/453)) ([0c67998](https://github.com/kurtosis-tech/ethereum-package/commit/0c67998567a4ab60dd0355b734076ee47b988326))
* logging bug ([#462](https://github.com/kurtosis-tech/ethereum-package/issues/462)) ([f6098a1](https://github.com/kurtosis-tech/ethereum-package/commit/f6098a1572923655426f25eab936b7a0b9fbc116))
* parallel key generation ([#423](https://github.com/kurtosis-tech/ethereum-package/issues/423)) ([060fd8f](https://github.com/kurtosis-tech/ethereum-package/commit/060fd8fb3ed8e12be895a43912787313c1ad4a5f))
* re-add networkid ([#464](https://github.com/kurtosis-tech/ethereum-package/issues/464)) ([4d96409](https://github.com/kurtosis-tech/ethereum-package/commit/4d96409cdbd1a367fc1e924cb9183eadce4eeae7))
* typo ([#445](https://github.com/kurtosis-tech/ethereum-package/issues/445)) ([e61c58a](https://github.com/kurtosis-tech/ethereum-package/commit/e61c58a8c2944cbf2699bd75d25a2e63d8e0621c))
* Update nethermind to expose host on 0.0.0.0 ([#467](https://github.com/kurtosis-tech/ethereum-package/issues/467)) ([0bd29dd](https://github.com/kurtosis-tech/ethereum-package/commit/0bd29dd7d61dae77b7820f79d46e8a52e74267c2))
* use all enrs for nimbus via bootstrap file ([#450](https://github.com/kurtosis-tech/ethereum-package/issues/450)) ([bb5a0c1](https://github.com/kurtosis-tech/ethereum-package/commit/bb5a0c1b5b051b23b185cfd366a2dfed3f44d903))

## [1.2.0](https://github.com/kurtosis-tech/ethereum-package/compare/1.1.0...1.2.0) (2024-01-03)


### Features

* add blobber ([#401](https://github.com/kurtosis-tech/ethereum-package/issues/401)) ([d2755b0](https://github.com/kurtosis-tech/ethereum-package/commit/d2755b011da5199273b9719395132f98c0c9d57d))
* add files artifact uuid information to cl client context ([#418](https://github.com/kurtosis-tech/ethereum-package/issues/418)) ([806ef47](https://github.com/kurtosis-tech/ethereum-package/commit/806ef47aefc4e22f79b6a96ad941b72ac5d5c099))
* add graffiti ([#408](https://github.com/kurtosis-tech/ethereum-package/issues/408)) ([21eae3b](https://github.com/kurtosis-tech/ethereum-package/commit/21eae3b58a607c3897943d692bbc62229eb534ca))
* add nethermind verkle example file ([#379](https://github.com/kurtosis-tech/ethereum-package/issues/379)) ([244d1ee](https://github.com/kurtosis-tech/ethereum-package/commit/244d1ee981d64b10ae73ef302fefb854d1580d40))
* add preregistered_validator_count network param field ([#426](https://github.com/kurtosis-tech/ethereum-package/issues/426)) ([d598018](https://github.com/kurtosis-tech/ethereum-package/commit/d598018afda5824cf6c365f23426a518ec83fe9a))
* add prysm latency dashboard ([#397](https://github.com/kurtosis-tech/ethereum-package/issues/397)) ([83b5b4e](https://github.com/kurtosis-tech/ethereum-package/commit/83b5b4e93d3e8579ef66b18f97dca46b83fcb72c))
* add resource requests/limits to most applications ([#396](https://github.com/kurtosis-tech/ethereum-package/issues/396)) ([c5728d9](https://github.com/kurtosis-tech/ethereum-package/commit/c5728d980f76be66bfb9ba3bbf275dbcaf5c5beb))
* allow 0 genesis delay ([#383](https://github.com/kurtosis-tech/ethereum-package/issues/383)) ([11c2693](https://github.com/kurtosis-tech/ethereum-package/commit/11c26939c53a6db0d8816254f6b7ac535535e754))
* enable teku split beacon &lt;&gt; validator setup ([#409](https://github.com/kurtosis-tech/ethereum-package/issues/409)) ([51f76bd](https://github.com/kurtosis-tech/ethereum-package/commit/51f76bd109036def06a5ad55cb72d9ab18a3b869))
* make eth1 follow distance configurable ([#433](https://github.com/kurtosis-tech/ethereum-package/issues/433)) ([a40f7dc](https://github.com/kurtosis-tech/ethereum-package/commit/a40f7dc83a610d96aa61ded96bbfe689c467748a))
* split nimbus CL-validator ([#404](https://github.com/kurtosis-tech/ethereum-package/issues/404)) ([cb33648](https://github.com/kurtosis-tech/ethereum-package/commit/cb33648d3df801bffac18a46ff84fec808956586))
* update ethereum-genesis-generator images ([#385](https://github.com/kurtosis-tech/ethereum-package/issues/385)) ([8959fc8](https://github.com/kurtosis-tech/ethereum-package/commit/8959fc80786c04200aecabcbbd426e47ead24ae4))
* use prometheus kurtosis package ([#399](https://github.com/kurtosis-tech/ethereum-package/issues/399)) ([c41a989](https://github.com/kurtosis-tech/ethereum-package/commit/c41a989e95f0c5bcb96987ef55fb673330132b6b))


### Bug Fixes

* ci was broken as it was using the wrong storage class for k3s ([#420](https://github.com/kurtosis-tech/ethereum-package/issues/420)) ([f957f85](https://github.com/kurtosis-tech/ethereum-package/commit/f957f8518b28c6fc3da0fd62f63d96517f717a9a))
* enable debug namespace in prysm ([#405](https://github.com/kurtosis-tech/ethereum-package/issues/405)) ([31badc2](https://github.com/kurtosis-tech/ethereum-package/commit/31badc238688fb409fba533fe8a237097c3577f4))
* ethereum-genesis-generator version for verkle genesis ([#395](https://github.com/kurtosis-tech/ethereum-package/issues/395)) ([d7c9b92](https://github.com/kurtosis-tech/ethereum-package/commit/d7c9b92f09c0c1f602f88cc604e63c0992eda182))
* fixing too long graffitis ([#410](https://github.com/kurtosis-tech/ethereum-package/issues/410)) ([a18935f](https://github.com/kurtosis-tech/ethereum-package/commit/a18935f52a44efaf00c9fb0fa104433018afb0c3))
* increase memory for blob spammer to prevent container from getting OOM killed ([#431](https://github.com/kurtosis-tech/ethereum-package/issues/431)) ([4d4fac0](https://github.com/kurtosis-tech/ethereum-package/commit/4d4fac0cc0e6fa58aa314ce301f0cfcc20026bef))
* mev workflow ([#434](https://github.com/kurtosis-tech/ethereum-package/issues/434)) ([91794e9](https://github.com/kurtosis-tech/ethereum-package/commit/91794e9fe2b7b08d50ee137a6b647479b9190d37))
* mev-boost naming scheme change ([#428](https://github.com/kurtosis-tech/ethereum-package/issues/428)) ([fce899b](https://github.com/kurtosis-tech/ethereum-package/commit/fce899bec2796a8b54f5a331721839a752e7040c))
* peering issue between lighthouse-teku on k8s ([#382](https://github.com/kurtosis-tech/ethereum-package/issues/382)) ([97a070b](https://github.com/kurtosis-tech/ethereum-package/commit/97a070b662e153404498dccb5b045f6e2ed510b0))
* peering issue with prysm and nimbus ([#416](https://github.com/kurtosis-tech/ethereum-package/issues/416)) ([132fc83](https://github.com/kurtosis-tech/ethereum-package/commit/132fc835ff8966ef671e1ecb61fc68765e81a16f))
* rename package icon for package catalog compatability ([#413](https://github.com/kurtosis-tech/ethereum-package/issues/413)) ([f49185b](https://github.com/kurtosis-tech/ethereum-package/commit/f49185b2a15be84e0ea8dc821ed39622dde104cc))
* roll out persistence for postgres on ethereum-package ([#421](https://github.com/kurtosis-tech/ethereum-package/issues/421)) ([ed3982b](https://github.com/kurtosis-tech/ethereum-package/commit/ed3982b5630c0bfdeb022f9853373d34e1f270cf))
* set persistence to false for blobscan ([#398](https://github.com/kurtosis-tech/ethereum-package/issues/398)) ([3c06194](https://github.com/kurtosis-tech/ethereum-package/commit/3c06194ca60b82b37d7a216fd6325100ebe72b0b))
* tx-spammer extra args ([#394](https://github.com/kurtosis-tech/ethereum-package/issues/394)) ([709b4ad](https://github.com/kurtosis-tech/ethereum-package/commit/709b4adc75e5c6bb7d6977edb43b9e5438f2bc7c))
* Update README.md remove teku coming soon ([#414](https://github.com/kurtosis-tech/ethereum-package/issues/414)) ([5a1ce2e](https://github.com/kurtosis-tech/ethereum-package/commit/5a1ce2e123353692614688cc4fae304bfe0a51e4))
* validator counting ([#425](https://github.com/kurtosis-tech/ethereum-package/issues/425)) ([698305a](https://github.com/kurtosis-tech/ethereum-package/commit/698305ad45f6ff4e200abe8a77c43b09120a5ed6))

## [1.1.0](https://github.com/kurtosis-tech/ethereum-package/compare/1.0.0...1.1.0) (2023-11-30)


### Features

* Add adminer ([#295](https://github.com/kurtosis-tech/ethereum-package/issues/295)) ([99b5913](https://github.com/kurtosis-tech/ethereum-package/commit/99b5913bfbc2ea25716b593cafbaebc486bf3c88))
* Add broadcaster ([#355](https://github.com/kurtosis-tech/ethereum-package/issues/355)) ([0f9c3aa](https://github.com/kurtosis-tech/ethereum-package/commit/0f9c3aad1f1360fa896dce75cb1b2c46e9872af1))
* add custom label configuration option ([#375](https://github.com/kurtosis-tech/ethereum-package/issues/375)) ([82ec85e](https://github.com/kurtosis-tech/ethereum-package/commit/82ec85e84e8c0972217f43962674493195970866))
* add custom labels ([#340](https://github.com/kurtosis-tech/ethereum-package/issues/340)) ([789ed8e](https://github.com/kurtosis-tech/ethereum-package/commit/789ed8e7f0a1a1512132732540a713dca17bbe56))
* add dencun example, bump teku mem, update mev-relay postgres name ([#369](https://github.com/kurtosis-tech/ethereum-package/issues/369)) ([1097531](https://github.com/kurtosis-tech/ethereum-package/commit/10975312c4d5c74b9bb80b872f205374997fc33c))
* Add Ethereum Metrics Exporter Dash ([#338](https://github.com/kurtosis-tech/ethereum-package/issues/338)) ([3ce9a78](https://github.com/kurtosis-tech/ethereum-package/commit/3ce9a780f50c4909b9fe64ccd6580432135e1c37))
* Add initial support for Blobscan ([#363](https://github.com/kurtosis-tech/ethereum-package/issues/363)) ([837fb97](https://github.com/kurtosis-tech/ethereum-package/commit/837fb970bb65d12bbe31dfec011a7f323d520111))
* add prometheus custom configuration for participants ([#354](https://github.com/kurtosis-tech/ethereum-package/issues/354)) ([e9bbc7d](https://github.com/kurtosis-tech/ethereum-package/commit/e9bbc7debf9db9c7f30271084b6276fcbe167d93))
* added a gitpod badge ([#356](https://github.com/kurtosis-tech/ethereum-package/issues/356)) ([e273993](https://github.com/kurtosis-tech/ethereum-package/commit/e2739935d8ed3993d7152a8403a194ea628360a2))
* Allow verkle to be at genesis or post genesis ([60a7529](https://github.com/kurtosis-tech/ethereum-package/commit/60a752932242d795e5c087094ca5e26f6f4029c4))
* differentiate builder ec by suffixing it with '-builder' ([#347](https://github.com/kurtosis-tech/ethereum-package/issues/347)) ([c558cb2](https://github.com/kurtosis-tech/ethereum-package/commit/c558cb2eab25cc8c3718b1fda6759a0819e6f942))


### Bug Fixes

* add java opts for besu ([#346](https://github.com/kurtosis-tech/ethereum-package/issues/346)) ([8aa88e3](https://github.com/kurtosis-tech/ethereum-package/commit/8aa88e34212321b2a148fd26c0e5a0da0b1a5b3f))
* blobscan lint error ([#374](https://github.com/kurtosis-tech/ethereum-package/issues/374)) ([32f862b](https://github.com/kurtosis-tech/ethereum-package/commit/32f862be000a547fba300be4be3f954835ac707f))
* builder args incorrectly configured ([#343](https://github.com/kurtosis-tech/ethereum-package/issues/343)) ([66e73fb](https://github.com/kurtosis-tech/ethereum-package/commit/66e73fb9f20d8dcce17beb00bf25dafb1e4ada65))
* network params setting invalid value for min/max configs ([#353](https://github.com/kurtosis-tech/ethereum-package/issues/353)) ([764b7dc](https://github.com/kurtosis-tech/ethereum-package/commit/764b7dc0577a8e8da9dac3519d18db51720f2b4b))
* update validator reward address ([#350](https://github.com/kurtosis-tech/ethereum-package/issues/350)) ([57f82c0](https://github.com/kurtosis-tech/ethereum-package/commit/57f82c0432c9a77bfa12f78a14b2e0038228a99c))
* Use unused accounts for mev flood ([#359](https://github.com/kurtosis-tech/ethereum-package/issues/359)) ([286654c](https://github.com/kurtosis-tech/ethereum-package/commit/286654c769b33c1d63d20bf31c1dd3a71f7a3f0d))

## [1.0.0](https://github.com/kurtosis-tech/ethereum-package/compare/0.6.1...1.0.0) (2023-10-25)


### ⚠ BREAKING CHANGES

* merged genesis generation ([#288](https://github.com/kurtosis-tech/ethereum-package/issues/288))

### Features

* add "disable_peer_scoring" global flag ([#311](https://github.com/kurtosis-tech/ethereum-package/issues/311)) ([63f7ff3](https://github.com/kurtosis-tech/ethereum-package/commit/63f7ff3c396ab567caf3397822ea7c2d614baeb9)), closes [#304](https://github.com/kurtosis-tech/ethereum-package/issues/304)
* add mock mev ci ([#310](https://github.com/kurtosis-tech/ethereum-package/issues/310)) ([d4bec9e](https://github.com/kurtosis-tech/ethereum-package/commit/d4bec9e7a723d1cdbbd37d63684b526a4f1f325b))
* add trusted setup file to teku ([#325](https://github.com/kurtosis-tech/ethereum-package/issues/325)) ([605e155](https://github.com/kurtosis-tech/ethereum-package/commit/605e155ee5e5058cc159739ee673eff4b702bc52))
* bump json-rpc-snooper ([#329](https://github.com/kurtosis-tech/ethereum-package/issues/329)) ([242a4cd](https://github.com/kurtosis-tech/ethereum-package/commit/242a4cdeded040eb50c9e259aacf9a58eee236ec))
* json to yaml everything ([#332](https://github.com/kurtosis-tech/ethereum-package/issues/332)) ([c9669ae](https://github.com/kurtosis-tech/ethereum-package/commit/c9669ae83063a5dd9faf478f386582a2cac595ac))
* merged genesis generation ([#288](https://github.com/kurtosis-tech/ethereum-package/issues/288)) ([743ba44](https://github.com/kurtosis-tech/ethereum-package/commit/743ba44d82e9433e6781e4965ef80bc83e962e25))
* rework how keys are generated ([#301](https://github.com/kurtosis-tech/ethereum-package/issues/301)) ([59f15ca](https://github.com/kurtosis-tech/ethereum-package/commit/59f15cae142b778a676ee6a3f56d4c8e3a2ed1c0))
* **tooling:** Add Ethereum Metrics Exporter ([#331](https://github.com/kurtosis-tech/ethereum-package/issues/331)) ([de5eee8](https://github.com/kurtosis-tech/ethereum-package/commit/de5eee82a7757b218a902e0bef36dae42e966b31))
* use base image instead of pip install ([#322](https://github.com/kurtosis-tech/ethereum-package/issues/322)) ([18da90b](https://github.com/kurtosis-tech/ethereum-package/commit/18da90bd3f8b6471457e613edc1e17ff01d2ae0a))


### Bug Fixes

* add readme for mev-builder-cl-image ([#314](https://github.com/kurtosis-tech/ethereum-package/issues/314)) ([c46b6bf](https://github.com/kurtosis-tech/ethereum-package/commit/c46b6bf1e83fa567727675ef0644d7d3eefcb1f2))
* formatting - missing jwt secret ([#312](https://github.com/kurtosis-tech/ethereum-package/issues/312)) ([728964c](https://github.com/kurtosis-tech/ethereum-package/commit/728964c7034c94dff6b2c4479e7a962d69bafc62))
* genesis validators root had an extra new line ([#326](https://github.com/kurtosis-tech/ethereum-package/issues/326)) ([4fa4937](https://github.com/kurtosis-tech/ethereum-package/commit/4fa49375c0f0e96aaef011e0afd053c2975c3a69))
* geth flags for verkle genesis ([#328](https://github.com/kurtosis-tech/ethereum-package/issues/328)) ([e721373](https://github.com/kurtosis-tech/ethereum-package/commit/e721373f93e8113802c47e815f3152af5974dc41))
* path based storage - disable for older forks ([#336](https://github.com/kurtosis-tech/ethereum-package/issues/336)) ([76e3424](https://github.com/kurtosis-tech/ethereum-package/commit/76e34245dffcd6976d631d40cab813880b9a224a))
* path based storage disable for elecra ([#316](https://github.com/kurtosis-tech/ethereum-package/issues/316)) ([86fa8ef](https://github.com/kurtosis-tech/ethereum-package/commit/86fa8efccd18236d0cbbfd7565f66883cc774fcc))
* remove image name for ethereum-metrics-exporter ([#335](https://github.com/kurtosis-tech/ethereum-package/issues/335)) ([4bac042](https://github.com/kurtosis-tech/ethereum-package/commit/4bac04249f61a408f792d4eb65c6c1ea3b844f61))
* remove path based storage when builder is used ([#327](https://github.com/kurtosis-tech/ethereum-package/issues/327)) ([d3cf3f4](https://github.com/kurtosis-tech/ethereum-package/commit/d3cf3f42ebe68b02cf28ad3d7c69c77e7c934af7))
* revert the default deneb at epoch 4 ([#323](https://github.com/kurtosis-tech/ethereum-package/issues/323)) ([9342418](https://github.com/kurtosis-tech/ethereum-package/commit/9342418fc643fbf41a95db828ec5fcd3be4913cf))
* take out the genesis versions as constants ([#324](https://github.com/kurtosis-tech/ethereum-package/issues/324)) ([a8afcef](https://github.com/kurtosis-tech/ethereum-package/commit/a8afcef6a8969ad2062c78f1b2d32e275697ea60))
* wrong builder metrics flag ([#319](https://github.com/kurtosis-tech/ethereum-package/issues/319)) ([51a4422](https://github.com/kurtosis-tech/ethereum-package/commit/51a44228994e2c0088ffccb3c2cca60376087bff))
* zero count validators and parallel keystore generation ([#302](https://github.com/kurtosis-tech/ethereum-package/issues/302)) ([18b141e](https://github.com/kurtosis-tech/ethereum-package/commit/18b141edf901b39c7ddc8cc60ba81b5185d4e15e))

## [0.6.1](https://github.com/kurtosis-tech/ethereum-package/compare/0.6.0...0.6.1) (2023-10-17)


### Bug Fixes

* `get_transaction_count` does not count pending transactions ([#299](https://github.com/kurtosis-tech/ethereum-package/issues/299)) ([2c64de0](https://github.com/kurtosis-tech/ethereum-package/commit/2c64de058ff0b8b207b6f6908c2daa6c321f12c4))
* big table spin up logic for k8s ([#298](https://github.com/kurtosis-tech/ethereum-package/issues/298)) ([e01ce16](https://github.com/kurtosis-tech/ethereum-package/commit/e01ce1602addba1eb132ebbe0c03439fdf060f58))

## [0.6.0](https://github.com/kurtosis-tech/ethereum-package/compare/0.5.1...0.6.0) (2023-10-17)


### Features

* Add builder metrics to default mev builder ([#277](https://github.com/kurtosis-tech/ethereum-package/issues/277)) ([d0eff2e](https://github.com/kurtosis-tech/ethereum-package/commit/d0eff2e9dd39411e71e1d36f9d0e66041ff33c0a))
* Add configurable spamming frequency to custom flood ([#283](https://github.com/kurtosis-tech/ethereum-package/issues/283)) ([f1e18ca](https://github.com/kurtosis-tech/ethereum-package/commit/f1e18ca7440ff9494b9a6bf6c20aa97a695d6084))
* add full beacon chain explorer ([#253](https://github.com/kurtosis-tech/ethereum-package/issues/253)) ([1eddda5](https://github.com/kurtosis-tech/ethereum-package/commit/1eddda5e61ecb86687ca2eae8d691a58cdafbd45))
* add inputs for additional grafana dashboards ([#279](https://github.com/kurtosis-tech/ethereum-package/issues/279)) ([ad02c43](https://github.com/kurtosis-tech/ethereum-package/commit/ad02c43c661de9151e541852520fd9f8e68fd0d1))
* added another blob spamming tool (`goomy_blob`) ([#268](https://github.com/kurtosis-tech/ethereum-package/issues/268)) ([3f2c797](https://github.com/kurtosis-tech/ethereum-package/commit/3f2c797900cf1bfbef9b3dcac35b204e3a258b69))
* Adding 4788 deployment ([#275](https://github.com/kurtosis-tech/ethereum-package/issues/275)) ([1c7de29](https://github.com/kurtosis-tech/ethereum-package/commit/1c7de293e44822aff2f26267285512c22d5f139c))
* return participants, timestamp of genesis and validator root for consumers ([#262](https://github.com/kurtosis-tech/ethereum-package/issues/262)) ([3f2ea88](https://github.com/kurtosis-tech/ethereum-package/commit/3f2ea88bb4792ececf7f723c72bce704effc016b))
* update ethereum-genesis-generator ([#260](https://github.com/kurtosis-tech/ethereum-package/issues/260)) ([a5b939c](https://github.com/kurtosis-tech/ethereum-package/commit/a5b939caa171f8cb7ab3979939f114a8b6398db7))


### Bug Fixes

* Add disable peer scoring ([#247](https://github.com/kurtosis-tech/ethereum-package/issues/247)) ([c75af3c](https://github.com/kurtosis-tech/ethereum-package/commit/c75af3cf3215d3aac3eb2d11eafdf9f3c7729512))
* editor config used tabs still ([#274](https://github.com/kurtosis-tech/ethereum-package/issues/274)) ([7bbba4c](https://github.com/kurtosis-tech/ethereum-package/commit/7bbba4c2b77abbc27efcb2a9af352af6cc932f9b))
* enable trace http-api for reth ([#251](https://github.com/kurtosis-tech/ethereum-package/issues/251)) ([ba47763](https://github.com/kurtosis-tech/ethereum-package/commit/ba4776365fca21c0a3a0e841834d7379443b76be))
* explicitly set persist to false ([#296](https://github.com/kurtosis-tech/ethereum-package/issues/296)) ([37d8ccd](https://github.com/kurtosis-tech/ethereum-package/commit/37d8ccd86da44bc2e8fd60150c36068d36c2cb8b))
* fix dora image ([#270](https://github.com/kurtosis-tech/ethereum-package/issues/270)) ([19fe54a](https://github.com/kurtosis-tech/ethereum-package/commit/19fe54a7ee5b9ced651c8f867c5b38b5ea529d8b))
* fix the tx_fuzzer params ([#278](https://github.com/kurtosis-tech/ethereum-package/issues/278)) ([b0ee145](https://github.com/kurtosis-tech/ethereum-package/commit/b0ee145e94bc1b02a4dde48f198ab97357fd1ce9))
* get rid of explorer type ([#280](https://github.com/kurtosis-tech/ethereum-package/issues/280)) ([f5595f4](https://github.com/kurtosis-tech/ethereum-package/commit/f5595f4cbb4307a0b14e9bf379a1823c40d7e170))
* Pass all beacons to the relay ([#226](https://github.com/kurtosis-tech/ethereum-package/issues/226)) ([b4fde3d](https://github.com/kurtosis-tech/ethereum-package/commit/b4fde3d064e498a14410f776a76d23af97fd4f0f))
* re run custom flood whenever it crashes ([#264](https://github.com/kurtosis-tech/ethereum-package/issues/264)) ([fab3995](https://github.com/kurtosis-tech/ethereum-package/commit/fab39957b28dbd9731cc15ec2fde242d7d71f5e3)), closes [#245](https://github.com/kurtosis-tech/ethereum-package/issues/245)
* readme deadlink ([#269](https://github.com/kurtosis-tech/ethereum-package/issues/269)) ([f380cc4](https://github.com/kurtosis-tech/ethereum-package/commit/f380cc4c70e6c5a4f7d5fd0a755231eaf232a31b))
* remove engine from http-api list for reth ([#249](https://github.com/kurtosis-tech/ethereum-package/issues/249)) ([b3114d1](https://github.com/kurtosis-tech/ethereum-package/commit/b3114d130f8a551853aac9774d864e8b7d36775a))
* return data about pariticpants even if no additional services are launched ([#273](https://github.com/kurtosis-tech/ethereum-package/issues/273)) ([d29f98e](https://github.com/kurtosis-tech/ethereum-package/commit/d29f98e580afeca3a5d6d305f607d6f297606b9b))
* set MEV image to 0.26.0 and complain if capella is zero with MEV set to full ([#261](https://github.com/kurtosis-tech/ethereum-package/issues/261)) ([9dfc4de](https://github.com/kurtosis-tech/ethereum-package/commit/9dfc4de19045ee2fd5be4eac31c341921d984e3d))
* use 0.27 as the mev boost image ([839af19](https://github.com/kurtosis-tech/ethereum-package/commit/839af1986480dec245b03e91a927d693526cd1a1))
* use ethpandaops/erigon as its multiarch ([839af19](https://github.com/kurtosis-tech/ethereum-package/commit/839af1986480dec245b03e91a927d693526cd1a1))

## [0.5.1](https://github.com/kurtosis-tech/ethereum-package/compare/0.5.0...0.5.1) (2023-09-28)


### Bug Fixes

* enable all apis for reth ([#241](https://github.com/kurtosis-tech/ethereum-package/issues/241)) ([db92f7b](https://github.com/kurtosis-tech/ethereum-package/commit/db92f7b01be1dd05c65eb88463dee76f2261f42f))
* rename light-beaconchain-explorer to dora-the-explorer & change db location ([#243](https://github.com/kurtosis-tech/ethereum-package/issues/243)) ([d3a4b49](https://github.com/kurtosis-tech/ethereum-package/commit/d3a4b495873eeb25647a113f3cd39ab42029faf8))

## [0.5.0](https://github.com/kurtosis-tech/ethereum-package/compare/0.4.0...0.5.0) (2023-09-28)


### ⚠ BREAKING CHANGES

* rename the package to ethereum-package ([#234](https://github.com/kurtosis-tech/ethereum-package/issues/234))

### Features

* add generic prometheus endpoints ([#209](https://github.com/kurtosis-tech/ethereum-package/issues/209)) ([d04e85f](https://github.com/kurtosis-tech/ethereum-package/commit/d04e85f4ce6b82b989a07087cf20fdd4c984573b))


### Bug Fixes

* add an MIT licence ([#246](https://github.com/kurtosis-tech/ethereum-package/issues/246)) ([f632ff1](https://github.com/kurtosis-tech/ethereum-package/commit/f632ff14cacf6aab9aab6ab29ef94b4b87848f90))
* make nimbus work with mev components ([#244](https://github.com/kurtosis-tech/ethereum-package/issues/244)) ([5c64ed5](https://github.com/kurtosis-tech/ethereum-package/commit/5c64ed5efcc064799d5c6154d3e7e9ca2d6343ef))


### Code Refactoring

* rename the package to ethereum-package ([#234](https://github.com/kurtosis-tech/ethereum-package/issues/234)) ([23e4d5e](https://github.com/kurtosis-tech/ethereum-package/commit/23e4d5ecdc24ef9a463cbe4a58ded162f79d0d1f))

## [0.4.0](https://github.com/kurtosis-tech/ethereum-package/compare/0.3.1...0.4.0) (2023-09-27)


### ⚠ BREAKING CHANGES

* merge eth-network-package onto ethereum-package ([#228](https://github.com/kurtosis-tech/ethereum-package/issues/228))

### Code Refactoring

* merge eth-network-package onto ethereum-package ([#228](https://github.com/kurtosis-tech/ethereum-package/issues/228)) ([b72dad3](https://github.com/kurtosis-tech/ethereum-package/commit/b72dad35ac0991a6a33e8720aaa5c9455d34752b))

## [0.3.1](https://github.com/kurtosis-tech/ethereum-package/compare/0.3.0...0.3.1) (2023-09-26)


### Features

* add blobspammer ([f166d71](https://github.com/kurtosis-tech/ethereum-package/commit/f166d714ac7f708f533ab3006b051da0859017a3))
* add blobspammer  ([#165](https://github.com/kurtosis-tech/ethereum-package/issues/165)) ([f166d71](https://github.com/kurtosis-tech/ethereum-package/commit/f166d714ac7f708f533ab3006b051da0859017a3))
* add support for electra ([#176](https://github.com/kurtosis-tech/ethereum-package/issues/176)) ([fbe6c00](https://github.com/kurtosis-tech/ethereum-package/commit/fbe6c004e5a9e47e4e819eddea7d2b424a555634))
* Add Tx_spamer_params and move MEV to the bottom of main.star ([#208](https://github.com/kurtosis-tech/ethereum-package/issues/208)) ([23628b2](https://github.com/kurtosis-tech/ethereum-package/commit/23628b27a8d571df1c90c5cbe84455c7382e091c))
* added a reliable flooder ([#186](https://github.com/kurtosis-tech/ethereum-package/issues/186)) ([8146ab7](https://github.com/kurtosis-tech/ethereum-package/commit/8146ab7b7d90817ca93a1ed2569a57aa64903231))
* all_el_metrics ([#195](https://github.com/kurtosis-tech/ethereum-package/issues/195)) ([3bbcca7](https://github.com/kurtosis-tech/ethereum-package/commit/3bbcca70346d6e1f67bec2023543404df832ffa6))
* Allow selection of additional services ([#220](https://github.com/kurtosis-tech/ethereum-package/issues/220)) ([57b15fe](https://github.com/kurtosis-tech/ethereum-package/commit/57b15fe49479e0aaada3379782f4e668b3bfdf71))
* Make args optional ([#190](https://github.com/kurtosis-tech/ethereum-package/issues/190)) ([a3ad030](https://github.com/kurtosis-tech/ethereum-package/commit/a3ad030810b2c0d3be02b52d6d6c4ccb17c1e5c0))
* pass slots per epoch to mev-boost-relay ([#188](https://github.com/kurtosis-tech/ethereum-package/issues/188)) ([14acb6f](https://github.com/kurtosis-tech/ethereum-package/commit/14acb6f94b9a43508e40ce61cb198f6c59425dc5))


### Bug Fixes

* bring back wait for capella fork epoch ([#212](https://github.com/kurtosis-tech/ethereum-package/issues/212)) ([c7cce7e](https://github.com/kurtosis-tech/ethereum-package/commit/c7cce7ea39c4030ded65400a75b75ca7389fe2cc))
* bug with participant counts that lead to more than needed participants ([#221](https://github.com/kurtosis-tech/ethereum-package/issues/221)) ([7b93f1c](https://github.com/kurtosis-tech/ethereum-package/commit/7b93f1ceb2d4f1311efd5fc6691c1ad95623ab83))
* dont wait for epoch 1 and launch MEV before tx-fuzz ([#210](https://github.com/kurtosis-tech/ethereum-package/issues/210)) ([8b883af](https://github.com/kurtosis-tech/ethereum-package/commit/8b883aff7811a2f36a36531be1c047d087c0ac93))
* fail capella fork epoch ([#196](https://github.com/kurtosis-tech/ethereum-package/issues/196)) ([ebff2d0](https://github.com/kurtosis-tech/ethereum-package/commit/ebff2d0b85a3da08725d88a5c4ce284cf28ef79b))
* fix mismatch between validator_count & metrics gazer ([#223](https://github.com/kurtosis-tech/ethereum-package/issues/223)) ([5dd4f9b](https://github.com/kurtosis-tech/ethereum-package/commit/5dd4f9b352a571775684b30fe6fd530512fa943b))
* Improve MEV setup to use less containers for non_validator nodes ([#224](https://github.com/kurtosis-tech/ethereum-package/issues/224)) ([bd176f0](https://github.com/kurtosis-tech/ethereum-package/commit/bd176f08941300c98740adc82a0cf0f03694c569))
* Kevin/postgres package upgrade ([#179](https://github.com/kurtosis-tech/ethereum-package/issues/179)) ([1bcc623](https://github.com/kurtosis-tech/ethereum-package/commit/1bcc623f6e2a260751869b3b519b759bf510a994))
* Kevin/unpin redis version ([#182](https://github.com/kurtosis-tech/ethereum-package/issues/182)) ([4eb7127](https://github.com/kurtosis-tech/ethereum-package/commit/4eb7127816098a4615f061e0203b7e162d4b3a75))
* lodestar flag ([#217](https://github.com/kurtosis-tech/ethereum-package/issues/217)) ([5f1e0f2](https://github.com/kurtosis-tech/ethereum-package/commit/5f1e0f2943a006426b638c0699ddd58c47cc57c0))
* mev should work with the validator count change ([#225](https://github.com/kurtosis-tech/ethereum-package/issues/225)) ([37dccce](https://github.com/kurtosis-tech/ethereum-package/commit/37dccce1c1a1760b1ecac9264985a844f0db46a6))
* mev-boost creation by making it depend on actual participant count ([#191](https://github.com/kurtosis-tech/ethereum-package/issues/191)) ([7606cff](https://github.com/kurtosis-tech/ethereum-package/commit/7606cffafc054153dc4ad43d925dad7cfa4a9984))
* Mock builder updates ([#193](https://github.com/kurtosis-tech/ethereum-package/issues/193)) ([6cc3697](https://github.com/kurtosis-tech/ethereum-package/commit/6cc369703f821da788d49c9418e1b4008796ce95))
* parse input ([#205](https://github.com/kurtosis-tech/ethereum-package/issues/205)) ([a787b38](https://github.com/kurtosis-tech/ethereum-package/commit/a787b38d8c8e61008244818581bf5d9a3103bd33))
* pass through env var now for builder_signing_tx_key ([#207](https://github.com/kurtosis-tech/ethereum-package/issues/207)) ([a63f2fd](https://github.com/kurtosis-tech/ethereum-package/commit/a63f2fd78613607dd4be195eb002fa9af3c6a894))
* Pin Redis version in prep for package catalog version upgrade ([#180](https://github.com/kurtosis-tech/ethereum-package/issues/180)) ([09b235a](https://github.com/kurtosis-tech/ethereum-package/commit/09b235a37f62c2fd6f99dd466a9918d7d468831d))
* remove hardcoding of addresses in MEV flood ([#184](https://github.com/kurtosis-tech/ethereum-package/issues/184)) ([21b0975](https://github.com/kurtosis-tech/ethereum-package/commit/21b0975f20a955354482092f5f04fcb4a85114b0))
* replace plan.assert with plan.verify ([#202](https://github.com/kurtosis-tech/ethereum-package/issues/202)) ([073135d](https://github.com/kurtosis-tech/ethereum-package/commit/073135ddc8ab5fb912b20bae96ec2ec72c3ac2f4))
* start boost immediately after relay starts running ([#213](https://github.com/kurtosis-tech/ethereum-package/issues/213)) ([b6ce1e9](https://github.com/kurtosis-tech/ethereum-package/commit/b6ce1e9132ded99c1398353fa4324bbf9fb6e78c))
* update readme for MEV params ([#189](https://github.com/kurtosis-tech/ethereum-package/issues/189)) ([c1bf13e](https://github.com/kurtosis-tech/ethereum-package/commit/c1bf13ee737f3437d0aca7cf3bfd9753e2f31d43))
* use 4th private key (index 3) for tx fuzz like before ([#215](https://github.com/kurtosis-tech/ethereum-package/issues/215)) ([1752ed0](https://github.com/kurtosis-tech/ethereum-package/commit/1752ed0a9861c0a2f7fb313dbe44a800e419b6bc))
* use the third address instead of coinbase for tx-fuzz ([#185](https://github.com/kurtosis-tech/ethereum-package/issues/185)) ([3b2993c](https://github.com/kurtosis-tech/ethereum-package/commit/3b2993c050172dec63c26d9b53c53fc7a77ad079))

## [0.3.0](https://github.com/kurtosis-tech/ethereum-package/compare/0.2.0...0.3.0) (2023-09-03)


### ⚠ BREAKING CHANGES

* Uses the `plan` object. Users will have to update their Kurtosis CLI to >= 0.63.0 and restart the engine

### Features

* add beacon-metrics-gazer + beacon-metrics-gazer grafana dashboard ([#114](https://github.com/kurtosis-tech/ethereum-package/issues/114)) ([5540587](https://github.com/kurtosis-tech/ethereum-package/commit/55405874ee50826b65dc2a5664e2b8bf9d7f668b))
* add deneb support ([#96](https://github.com/kurtosis-tech/ethereum-package/issues/96)) ([07ed500](https://github.com/kurtosis-tech/ethereum-package/commit/07ed500890ab01b6bed04cdacc19b9373e6a4b6a))
* add ethereumjs to nightly runners ([b86d886](https://github.com/kurtosis-tech/ethereum-package/commit/b86d886197ddad2d0ea78efac7e11109838b5dd9))
* add ethereumjs to nightly runners ([#154](https://github.com/kurtosis-tech/ethereum-package/issues/154)) ([b86d886](https://github.com/kurtosis-tech/ethereum-package/commit/b86d886197ddad2d0ea78efac7e11109838b5dd9))
* add forkmon ([#107](https://github.com/kurtosis-tech/ethereum-package/issues/107)) ([2a8ad19](https://github.com/kurtosis-tech/ethereum-package/commit/2a8ad19e8ad9c4202bd6dc9dff28eb3ea2cf08f2))
* add light-beaconchain-explorer ([83e01a1](https://github.com/kurtosis-tech/ethereum-package/commit/83e01a114a3bad970ebecc2ae10bc863e14cdb3a))
* add light-beaconchain-explorer ([#125](https://github.com/kurtosis-tech/ethereum-package/issues/125)) ([83e01a1](https://github.com/kurtosis-tech/ethereum-package/commit/83e01a114a3bad970ebecc2ae10bc863e14cdb3a))
* add multiple endpoint support for lightbeaconchain expolorer ([#151](https://github.com/kurtosis-tech/ethereum-package/issues/151)) ([68572cd](https://github.com/kurtosis-tech/ethereum-package/commit/68572cdddb1e2074892f148b69e603a2ee06edb8))
* counting by summing each participant ([f9b638b](https://github.com/kurtosis-tech/ethereum-package/commit/f9b638bc1c26be34fd3dd0ad6e4d59ee4ecd66c3))
* counting by summing each participant ([#112](https://github.com/kurtosis-tech/ethereum-package/issues/112)) ([f9b638b](https://github.com/kurtosis-tech/ethereum-package/commit/f9b638bc1c26be34fd3dd0ad6e4d59ee4ecd66c3))
* disable login for grafana ([4d7df4b](https://github.com/kurtosis-tech/ethereum-package/commit/4d7df4be895b950119d1e5fabe0e4ae3cc0c822e))
* disable login for grafana ([#122](https://github.com/kurtosis-tech/ethereum-package/issues/122)) ([4d7df4b](https://github.com/kurtosis-tech/ethereum-package/commit/4d7df4be895b950119d1e5fabe0e4ae3cc0c822e))
* **formatting:** Add editorconfig, move everything to using tabs (4) ([#106](https://github.com/kurtosis-tech/ethereum-package/issues/106)) ([cb0fc69](https://github.com/kurtosis-tech/ethereum-package/commit/cb0fc695cce7a64386349193ef3cd3ebf692f18d))
* launch the mock mev builder ([#94](https://github.com/kurtosis-tech/ethereum-package/issues/94)) ([7fcd3e2](https://github.com/kurtosis-tech/ethereum-package/commit/7fcd3e24aa1d1c23afa0c37ba3c939c204720d31))
* make it possible to have capella on epoch 0 or non 0 ([#108](https://github.com/kurtosis-tech/ethereum-package/issues/108)) ([1133497](https://github.com/kurtosis-tech/ethereum-package/commit/1133497b18c6fa46f2b6483c9b2eea27bc272868))
* make mev more configurable ([#164](https://github.com/kurtosis-tech/ethereum-package/issues/164)) ([0165ef1](https://github.com/kurtosis-tech/ethereum-package/commit/0165ef1a67a77dfca2030c1b36ed12d00ae48d18))
* parameterize mev_boost and  mev_builder images ([#171](https://github.com/kurtosis-tech/ethereum-package/issues/171)) ([28adec1](https://github.com/kurtosis-tech/ethereum-package/commit/28adec114779e0b5946705038cb19c859c430242))
* snooper support ([#121](https://github.com/kurtosis-tech/ethereum-package/issues/121)) ([d2cccf4](https://github.com/kurtosis-tech/ethereum-package/commit/d2cccf4af8873a912cc4389f8db75ce4e11e2e44))
* support full MEV ([#115](https://github.com/kurtosis-tech/ethereum-package/issues/115)) ([e9e8c41](https://github.com/kurtosis-tech/ethereum-package/commit/e9e8c418c4a7a9ff099b4514430f8235f4ad1331))
* use eth-network-package to spin up participant network ([#90](https://github.com/kurtosis-tech/ethereum-package/issues/90)) ([91029ac](https://github.com/kurtosis-tech/ethereum-package/commit/91029acfb7867c134baac3aaf758eb06f67fe997))


### Bug Fixes

* a bug around participants ([#129](https://github.com/kurtosis-tech/ethereum-package/issues/129)) ([9382767](https://github.com/kurtosis-tech/ethereum-package/commit/9382767f88690817de189a3551c37325389faf98))
* delay deneb to 500 epoch ([#102](https://github.com/kurtosis-tech/ethereum-package/issues/102)) ([d07270b](https://github.com/kurtosis-tech/ethereum-package/commit/d07270bc9802fe2adc44d70e6e8e9c274958eacb))
* dont spin up extra el/cl client for mock-mev ([#158](https://github.com/kurtosis-tech/ethereum-package/issues/158)) ([46d67fc](https://github.com/kurtosis-tech/ethereum-package/commit/46d67fc5878a01984623c8f3ac9f667d1fb891f2))
* fix an arg parsing bug ([#135](https://github.com/kurtosis-tech/ethereum-package/issues/135)) ([f084e7c](https://github.com/kurtosis-tech/ethereum-package/commit/f084e7c72738b7afd71d9a1a05f6fba4c388a5de))
* fix passed argument parsing ([#85](https://github.com/kurtosis-tech/ethereum-package/issues/85)) ([a5d40e9](https://github.com/kurtosis-tech/ethereum-package/commit/a5d40e9bd178ff7ade06f22818475d01546f861a))
* fixed teku validator params for MEV ([#149](https://github.com/kurtosis-tech/ethereum-package/issues/149)) ([b0079cf](https://github.com/kurtosis-tech/ethereum-package/commit/b0079cff08b7c5812e97151ba56a0929593516ba))
* fixing nimbus payload url ([#155](https://github.com/kurtosis-tech/ethereum-package/issues/155)) ([55c1f59](https://github.com/kurtosis-tech/ethereum-package/commit/55c1f59404872c26315844995cbea6a4286b1cb2))
* geth failing after ethash package removal ([#93](https://github.com/kurtosis-tech/ethereum-package/issues/93)) ([41e3d2c](https://github.com/kurtosis-tech/ethereum-package/commit/41e3d2cd292dd19b805e5c93f3d65ec0ba063104)), closes [#91](https://github.com/kurtosis-tech/ethereum-package/issues/91)
* make besu a bootnode ([29296cd](https://github.com/kurtosis-tech/ethereum-package/commit/29296cd1c78615743d32f68ca50fb51121c5921c))
* make besu a bootnode ([#146](https://github.com/kurtosis-tech/ethereum-package/issues/146)) ([29296cd](https://github.com/kurtosis-tech/ethereum-package/commit/29296cd1c78615743d32f68ca50fb51121c5921c))
* make this work with kurtosis 0.65.0 ([#73](https://github.com/kurtosis-tech/ethereum-package/issues/73)) ([13c72ec](https://github.com/kurtosis-tech/ethereum-package/commit/13c72ec56e4da79c6a9bd6802a0995c6b00d0a0a))
* mention reth in package readme ([#133](https://github.com/kurtosis-tech/ethereum-package/issues/133)) ([d11a689](https://github.com/kurtosis-tech/ethereum-package/commit/d11a6898b9f7377a5e8c50ccd3859ec5eed0e556))
* move parallel keystore generation to global config ([0789eed](https://github.com/kurtosis-tech/ethereum-package/commit/0789eedb1f77c418944a2cc7047edd95256d983d))
* move parallel keystore generation to global config ([#130](https://github.com/kurtosis-tech/ethereum-package/issues/130)) ([0789eed](https://github.com/kurtosis-tech/ethereum-package/commit/0789eedb1f77c418944a2cc7047edd95256d983d))
* nightly tests that rely on etherejums get the right image ([#159](https://github.com/kurtosis-tech/ethereum-package/issues/159)) ([97b4d33](https://github.com/kurtosis-tech/ethereum-package/commit/97b4d33aa4c236e9615df7f3c62e6221a056385f))
* Nimbus can't run when slot time is below 12s ([#100](https://github.com/kurtosis-tech/ethereum-package/issues/100)) ([c38bff9](https://github.com/kurtosis-tech/ethereum-package/commit/c38bff9f5d6d49f57c1a66c84828f8bad9c550cc))
* pass right mev-boost url to teku ([#147](https://github.com/kurtosis-tech/ethereum-package/issues/147)) ([8bb75d9](https://github.com/kurtosis-tech/ethereum-package/commit/8bb75d91b9a45a5a2fc7e64118d5913ffef138f4))
* pin postgres package ([#174](https://github.com/kurtosis-tech/ethereum-package/issues/174)) ([6b8d9d3](https://github.com/kurtosis-tech/ethereum-package/commit/6b8d9d39fd06d1dc01d4f3cbbc6c20f9f962bb6a))
* Remove nethermind restriction ([#126](https://github.com/kurtosis-tech/ethereum-package/issues/126)) ([373c6c9](https://github.com/kurtosis-tech/ethereum-package/commit/373c6c9b45ac4fc9bee930bc5430921cd3a16a1f))
* Switch default images to latest ([#99](https://github.com/kurtosis-tech/ethereum-package/issues/99)) ([4a85c9d](https://github.com/kurtosis-tech/ethereum-package/commit/4a85c9dccb0e5cbd809ed7047b78e7190d466a91))
* Update enclave name flag ([#87](https://github.com/kurtosis-tech/ethereum-package/issues/87)) ([6531a7a](https://github.com/kurtosis-tech/ethereum-package/commit/6531a7af37faa2d227a2a53739ca7ae0cd4aed9e))
* update genesis generator to support netherminds new format ([#68](https://github.com/kurtosis-tech/ethereum-package/issues/68)) ([094352d](https://github.com/kurtosis-tech/ethereum-package/commit/094352d6666755da5de6ed3f4b78fd5f37c01f7f))
* update nightly runner ([#163](https://github.com/kurtosis-tech/ethereum-package/issues/163)) ([4eba65d](https://github.com/kurtosis-tech/ethereum-package/commit/4eba65df4fd29ece8a89ac77066e68d330fc2297))
* use eth maintained tx-fuzz ([#110](https://github.com/kurtosis-tech/ethereum-package/issues/110)) ([b0903bd](https://github.com/kurtosis-tech/ethereum-package/commit/b0903bdae490ffa30251ddede9edca21105fba48))
* use flashbots builder ([#162](https://github.com/kurtosis-tech/ethereum-package/issues/162)) ([7a0c2d0](https://github.com/kurtosis-tech/ethereum-package/commit/7a0c2d03dff1dd0ee5c92b5c2f9478f4e56f6920))
* use mev-boost-relay by flashbots ([#141](https://github.com/kurtosis-tech/ethereum-package/issues/141)) ([fca62fc](https://github.com/kurtosis-tech/ethereum-package/commit/fca62fcee23525cc891eaf2494a2b1cb694f5bf4))
* use named artifacts ([#69](https://github.com/kurtosis-tech/ethereum-package/issues/69)) ([968f073](https://github.com/kurtosis-tech/ethereum-package/commit/968f0734a0ee834c75e184b758989ce1dc9d58be)), closes [#70](https://github.com/kurtosis-tech/ethereum-package/issues/70)
* Use plan object ([#65](https://github.com/kurtosis-tech/ethereum-package/issues/65)) ([8e5d185](https://github.com/kurtosis-tech/ethereum-package/commit/8e5d18558f92a9fc71ae9a70f1ca139df406d7b7))
* use v2 endoint to get the head block ([#153](https://github.com/kurtosis-tech/ethereum-package/issues/153)) ([f084711](https://github.com/kurtosis-tech/ethereum-package/commit/f084711061c777c78ef8f002a4f7e597c27e8eb5))
* work with latest eth-network-package ([14dc957](https://github.com/kurtosis-tech/ethereum-package/commit/14dc95776e16f8cdf8ac83a03c53abad489cb8f7))
* work with latest eth-network-package ([#116](https://github.com/kurtosis-tech/ethereum-package/issues/116)) ([14dc957](https://github.com/kurtosis-tech/ethereum-package/commit/14dc95776e16f8cdf8ac83a03c53abad489cb8f7))

## 0.2.0

- Adds config variables for `genesis_delay` and `capella_fork_epoch`
- Updates genesis generator version
- Fixes genesis timestamp such that the shanghai fork can happen based on timestamps
- Update `--enclave-id` flag to `--enclave` in README

### Breaking Change

- Introduced optional application protocol and renamed protocol to transport_protocol

## 0.1.0

### Breaking changes

- Updated `struct` to `PortSpec` for declaring port definitions

### Changes

- Change `exec` syntax

## 0.0.5

### Fixes

- Fix bug with input parsing of participants
- Fix bug with `get_enode_for_node` being assigned to two parameters

### Changes

- Updated `run(input_args)` to `run(args)`
- Refactor code to use `wait` and `request` commands
- Removed `print(output)` at the end as it is now printed by the framework
- Updates nimbus default docker image
- Updates `genesis-generator` image to include a fix for nimbus post-merge genesis
- Use the `args` argument instead of flags

## 0.0.4

### Changes

- Removed 'module' key in the 'kurtosis.yml' file

## 0.0.3

### Changes

- Replaced 'module' with 'package' where relevant
- Removed protobuf types as they are now unsupported in Kurtosis.
- Renamed `kurtotis.mod` to `kurtosis.yml`

### Fixes

- Fixed a bug in `run` of `main.star` where we'd refer to `module_io` instead of `package_io`

## 0.0.2

### Features

- Added the docs

### Fixes

- Renamed `num_validators_per_keynode` to `num_validator_keys_per_node`
- Moved away from `load` infavor of `import_module`
- Moved away from `store_files_from_service` to `store_service_files`
- Removed empty `ports` from a few service configs as passing it is now optional
- Adjusted to the new render templates config
- Moved away from passing json string to struct/dict for render templates

### Changes

- Move from `main` to `run` in `main.star`

## 0.0.1

### Features

- Changed the .circlei/config.yml to apply to Startosis
- Added genesis_constants
- Added a lot of participant_network/pre_launch_data_generator
- Added a lot of simple objects that just keep data
- Added monitoring on top of the repo
- Almost perfect parity with the eth2-merge-kurtosis-module

### Fixes

- Fixes some bugs with the initial implementation of the monitors

## 0.0.0

- Initial commit
