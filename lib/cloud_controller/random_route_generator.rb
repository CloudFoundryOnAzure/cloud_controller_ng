require 'set'

module VCAP::CloudController
  class RandomRouteGenerator
    Adjectives = 'accountable
  active
  agile
  anxious
  appreciative
  balanced
  boisterous
  bold
  boring
  brash
  brave
  bright
  busy
  chatty
  cheerful
  chipper
  comedic
  courteous
  daring
  delightful
  empathic
  excellent
  exhausted
  fantastic
  fearless
  fluent
  forgiving
  friendly
  funny
  generous
  grateful
  grouchy
  grumpy
  happy
  hilarious
  humble
  impressive
  insightful
  intelligent
  interested
  kind
  lean
  mediating
  meditating
  nice
  noisy
  optimistic
  palm
  patient
  persistent
  proud
  quick
  quiet
  reflective
  relaxed
  reliable
  responsible
  responsive
  rested
  restless
  shiny
  shy
  silly
  sleepy
  smart
  spontaneous
  surprised
  sweet
  talkative
  terrific
  thankful
  timely
  tired
  turbulent
  unexpected
  wacky
  wise
  zany'.split(/\s+/)

    Nouns = 'aardvark
  alligator
  antelope
  baboon
  badger
  bandicoot
  bat
  bear
  bilby
  bongo
  bonobo
  buffalo
  bushbuck
  camel
  cassowary
  cat
  cheetah
  chimpanzee
  chipmunk
  civet
  crane
  crocodile
  dingo
  dog
  dugong
  duiker
  echidna
  eland
  elephant
  emu
  fossa
  fox
  gazelle
  gecko
  gelada
  genet
  gerenuk
  giraffe
  gnu
  gorilla
  grysbok
  guanaco
  hartebeest
  hedgehog
  hippopotamus
  hyena
  hyrax
  impala
  jackal
  jaguar
  kangaroo
  klipspringer
  koala
  kob
  kookaburra
  kudu
  lemur
  leopard
  lion
  lizard
  llama
  lynx
  manatee
  mandrill
  marmot
  meerkat
  mongoose
  mouse
  numbat
  nyala
  okapi
  oribi
  oryx
  ostrich
  otter
  panda
  pangolin
  panther
  parrot
  platypus
  porcupine
  possum
  puku
  quokka
  quoll
  rabbit
  ratel
  raven
  reedbuck
  rhinocerous
  roan
  sable
  serval
  shark
  sitatunga
  springhare
  squirrel
  swan
  tiger
  topi
  toucan
  turtle
  vicuna
  wallaby
  warthog
  waterbuck
  whale
  whale1
  whale2
  whale9
  wildebeest
  wolf
  wolverine
  wombat
  zebra'.split(/\s+/)

    def initialize
      @rand = Random.new
    end

    def route
      "#{Adjectives[@rand.rand(Adjectives.size)]}-#{Nouns[@rand.rand(Nouns.size)]}"
    end

    def seed(val)
      @rand = Random.new(val)
    end
  end
end
