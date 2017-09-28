import std.stdio;

import layout;
import terminal;
import termapp;

import diesel.vec;
import diesel.gl.font;

import imageformats;

import luainterpreter : script;

class BindBase {
    abstract void call();
}

class Bind(FN, SOURCE) : BindBase {
    override void call() {
        fn(s);
    }
    FN fn;
    SOURCE s;
}

class Bind(FN, SOURCE : int delegate()) : BindBase {
    override void call() {
        fn(s());
    }
    FN fn;
    SOURCE s;
}

class Bind(FN, SOURCE : int[]) : BindBase {
    override void call() {
        fn(s[i]);
        i = (i + 1) % cast(int)s.length;
    }
    FN fn;
    SOURCE s;
    int i = 0;
}

class Bind(FN : void delegate(), SOURCE) : BindBase {
    override void call() {
        fn();
    }
    FN fn;
}

BindBase[uint] binds;

class TermOps
{
    TermApp app;
    alias NODE = Node!Terminal;
    alias app this;

    void bind(FN, SOURCE)(uint key, FN fn, SOURCE value)
    {
        auto b = new Bind!(FN, SOURCE);
        b.fn = fn;
        b.s = value;
        binds[key] = b;
    }

    void bind(uint key, void delegate() fn)
    {
        auto b = new Bind!(typeof(fn), void);
        b.fn = fn;
        binds[key] = b;
    }

    @script void bindKey(uint key, void delegate() fn)
    {
        auto b = new Bind!(typeof(fn), void);
        b.fn = fn;
        binds[key] = b;
    }

    bool handle(uint key)
    {
        auto ptr = (key in binds);
        if(ptr) {
            ptr.call();
            return true;
        }
        return false;
    }

    @script void setBorder(int b = -1) {
        border = b;
        writeln("BORDER " ,b);
        if(currentTerm) {
            currentTerm.border = b;
            currentTerm.resize();
        }
    }

        /* lua.registerFunction("setShader", (string b64data) { */
        /*     try { */
        /*         auto data = Base64.decode(b64data); */
        /*         setShader(cast(string)data); */
        /*     } catch (Exception e) { */
        /*         writeln("Failed to set shader"); */
        /*     } */
        /* }); */
        /* lua.registerFunction("setBackground", (string b64data) { */
        /*     try { */
        /*         auto data = Base64.decode(b64data); */
        /*         auto img = read_image_from_mem(data); */
        /*         background = Texture(img.w, img.h, cast(uint*)img.pixels.ptr); */
        /*     } catch (Exception e) { */
        /*         writeln("Failed to load bg"); */
        /*     } */
        /* }); */


    @script void setPalette(uint[] colors) {
        defaultPalette = colors;
        bgColor = vec3f(colors[0]);
        if(currentTerm)
            currentTerm.setPalette(colors);

    }

    @script void setFont(string spec) {
        writeln("SET FONT ", spec, win.getScale());
        Font font = new Font(spec, win.getScale());
        this.font = font;
        this.zoom = 1;
    }

    this(TermApp app) {
        this.app = app;
    }

    bool zoomed = false;
    NODE zoomedNode;
    NODE savedRoot;
    @script void toggleZoom() {
        if(!zoomed) {
            savedRoot = root;
            zoomedNode = currentNode;
            root = currentNode.detach();
            root.resize(savedRoot.x, savedRoot.y, savedRoot.w, savedRoot.h);
            currentNode = root;
            reorg();
        } else {
            root = savedRoot;
            root.resize(root.x, root.y, root.w, root.h);
            currentNode = zoomedNode;
            reorg();
        }
        zoomed = !zoomed;
    }

    @script void setTermScale(int scale)
    {
        if(currentTerm) {
            currentTerm.zoom = scale;
            currentTerm.resize();
        }
    }

    @script void setFontSize(int size)
    {
        if(currentTerm) {
            currentTerm.font.setSize(size * win.getScale());
            currentTerm.resize();
        }
    }

    // TODO: Split seems to leave both active = true ?
    @script void horizontalSplit()
    {
        NODE n;
        if(!currentNode.parent)
            return;
        if(!currentNode.parent.horizontal) {
            n = currentNode.parent.add();
        } else {
            auto nodes = currentNode.split();
            nodes[0].payload = currentNode.payload;
            currentNode.payload = null;
            n = nodes[1];
        }
        newTerm(n);
        currentTerm = n.payload;
    }

    @script void closeCurrent()
    {
        closeTerm(currentNode);
    }

    @script void verticalSplit()
    {
        NODE n;
        if(!currentNode.parent)
            return;
        if(currentNode.parent.horizontal) {
            n = currentNode.parent.add();
        } else {
            auto nodes = currentNode.split();
            nodes[0].payload = currentNode.payload;
            currentNode.payload = null;
            n = nodes[1];
        }
        newTerm(n);
        currentTerm = n.payload;
    }

    @script void equalizeAll()
    {
        /* root.forEach((NODE n) { */
        /*     n.weight = 1.0; */
        /*     n.parent.weight = 1.0; */
        /* }); */
        //root.layout();
        reorg();
    }

    @script void goUp()
    {
        if(!currentNode) return;
        if(lastNode && lastNode.findBelow() == currentNode)
            setTerm(lastNode);
        else
            setTerm(currentNode.findAbove());
    }

    @script void goDown()
    {
        if(!currentNode) return;
        if(lastNode && lastNode.findAbove() == currentNode)
            setTerm(lastNode);
        else
            setTerm(currentNode.findBelow());
    }

    @script void goLeft()
    {
        if(!currentNode) return;
        if(lastNode && lastNode.findRight() == currentNode)
            setTerm(lastNode);
        else
            setTerm(currentNode.findLeft());
    }

    @script void goRight()
    {
        if(lastNode && lastNode.findLeft() == currentNode)
            setTerm(lastNode);
        else
            setTerm(currentNode.findRight());
     }

    void grow(int n)
    {
        auto sz = currentNode.payload.font.size * n;
        resize([sz.x, sz.y]);
    }

    void shrink(int n)
    {
        auto sz = currentNode.payload.font.size * -n;
        resize([sz.x, sz.y]);
    }

    void paste()
    {
        Terminal ct = currentTerm;
        if(ct) {
            auto text = win.getClipboard();
            foreach(dchar c ; text)
                ct.putKey(c);
        }
    }

    void resize(int[2] delta)
    {
        auto x = delta[0];
        auto y = delta[1];

        auto nl = currentNode.findLeft();
        auto nr = currentNode.findRight();
        auto na = currentNode.findAbove();
        auto nb = currentNode.findBelow();
        if(nl) {
            auto s = getSplit(nl, currentNode);
            s.move(s.x - x, 0, minSplitSize);
        }
        if(nr) {
            auto s = getSplit(nr, currentNode);
            s.move(s.x + x, 0, minSplitSize);
        }
        if(na) {
            auto s = getSplit(na, currentNode);
            s.move(0, s.y - y, minSplitSize);
        }
        if(nb) {
            auto s = getSplit(nb, currentNode);
            s.move(0, s.y + y, minSplitSize);
        }
        root.print();
        reorg();
    }

    void takeScreenshot()
    {
        auto tex = currentTerm.console.screenTexture;
        auto d = tex.getPixels();
        auto data = new uint[d.length];
        int a = 0;
        int b = (tex.height-1) * tex.width;
        foreach(_ ; 0 .. tex.height) {
            data[a .. a+tex.width] = d[b .. b + tex.width];
            a += tex.width;
            b -= tex.width;
        }
        write_image("shot.tga", tex.width, tex.height, cast(const ubyte[])data);
    }

    @script void toast(string title)
    {
    }

    @script void onCommand(string pattern, void delegate() onStart, void delegate() onEnd)
    {

    }
}
