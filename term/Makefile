DUB_FLAGS :=
UNAME =$(shell uname)
ifeq ($(UNAME),Darwin)
  $(info ***** OSX detected)
  CONFIG := default
endif

ifeq ($(UNAME),Linux)
  ifneq ("$(wildcard /opt/vc/lib/libvcos.so)", "")
    $(info ***** Raspberry PI detected)
    CONFIG := raspberry
    DUB_FLAGS += --override-config=graphics/raspberry
  else
    $(info ***** Linux detected)
    CONFIG := default
  endif
endif

ifeq ("$(CONFIG)","")
    $(error ***** Unknown host system)
endif

DUB_FLAGS += --compiler=ldc2

debug :
	dub build --config=$(CONFIG) $(DUB_FLAGS) -b debug

release :
	dub build --config=$(CONFIG) $(DUB_FLAGS) -b release

profile :
	dub build --config=$(CONFIG) -b profile

trace :
	dub build --config=trace -b release

run :
	./jterm > /dev/null

clean :
	rm dub.selections.json
	dub clean

APP = JTerm.app/Contents
bundle :
	rm -rf JTerm.app
	mkdir -p $(APP)/MacOS
	cp jterm $(APP)/MacOS/
	cp misc/Info.plist $APP/

