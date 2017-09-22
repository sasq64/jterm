//  Split pane layout system;
//  A tree of `Nodes` that can resize itself
module layout;

import std.stdio;
import std.algorithm.searching : commonPrefix;
import std.algorithm.mutation : reverse;
import std.algorithm.comparison : max;


// A rectangle representation used by Nodes
struct NodeRec(T = uint)
{
    this(int w, int h)
    {
        this.w = w;
        this.h = h;
    }

    this(int x, int y, int w, int h)
    {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }

    string toString() {
        import std.string : format ;
        return format("[%d,%d %dx%d]", x,y,w,h);
    }

    // Split the rectangle in two
    NodeRec[2] split(float ratio, bool horiz = true) const
    {
        NodeRec[2] rc = [ this, this ];
        if(horiz) {
            rc[0].w = cast(T)(w * ratio);
            rc[1].w = cast(T)(w * (1.0-ratio));
            rc[1].x = rc[0].x + rc[0].w;
        } else {
            rc[0].h = cast(T)(h * ratio);
            rc[1].h = cast(T)(h * (1.0-ratio));
            rc[1].y = rc[0].y + rc[0].h;
        }
        return rc;
    }

    bool isInside(T)(T t) const {
        return (t[0] >= x && t[0] < (x+w) && t[1] >= y && t[1] < (y+h));
    }

    union {
        T[4] data;
        struct {
            T x;
            T y;
            T w;
            T h;
        };
    }

    alias data this;
};

alias IRec = NodeRec!int;


// The building block of the layout tree
class Node(PAYLOAD = int)
{
    invariant {
        if(parent) {
            assert(parent.horizontal == !horizontal);
            if(parent.horizontal) {
                assert(area.y == parent.area.y);
                assert(area.h == parent.area.h);
                assert(area.x >= parent.area.x);
                assert(area.w <= parent.area.w);
            } else {
                assert(area.x == parent.area.x);
                assert(area.w == parent.area.w);
                assert(area.y >= parent.area.y);
                assert(area.h <= parent.area.h);
            }
        }

        assert(weight > 0);
        assert(area.w > 0);
        assert(area.h > 0);

        if(child.length > 0) {
            float tw = 0;
            foreach(c ; child)
                tw += c.weight;
            assert(tw > 0.95 && tw < 1.05);
        }
    }

    Node parent;
    PAYLOAD payload;
    bool horizontal = true;

    private float weight = 1.0;
    private Node[] child;
    private IRec area;

    @property int x() const { return area.x; }
    @property int y() const { return area.y; }
    @property int w() const { return area.w; }
    @property int h() const { return area.h; }

    @property int childCount() const { return cast(int)child.length; }

    this(int x, int y, int w, int h, Node parent = null) {
        this.parent = parent;
        area = IRec(x,y,w,h);
    }

    this(uint w, uint h, Node parent = null) {
        this.parent = parent;
        area = IRec(w,h);
    }

    this(const IRec r, bool h = true, Node parent = null) {
        this.parent = parent;
        area = r;
        horizontal = h;
    }

    Node dup() {
        Node n = new Node(area, horizontal, parent);
        n.child = child;
        n.weight = weight;
        n.payload = payload;
        return n;
    }

    /// Resize the root node
    void resize(int x, int y, int w, int h) {
        assert(!parent);
        area.x = x;
        area.y = y;
        area.w = w;
        area.h = h;
        layout();
    }

    /// Remove this node from it's parent
    void remove() {
        static import std.algorithm.mutation;
        if(!parent)
            return;
        std.algorithm.mutation.remove!(c => c == this)(parent.child);
        parent.child.length--;
        if(parent.child.length == 0) {
            parent.remove();
        } else parent.layout();
    }

    /// Returns a copy that can stand on it's own
    Node detach() {
        auto n = dup();
        n.parent = null;
        return n;
    }

    /// Find the first none-null payload
    PAYLOAD firstPayload() {
        foreach(c ; child) {
            if(c.payload) return c.payload;
        }
        foreach(c ; child) {
            auto payload = c.firstPayload();
            if(payload) return payload;
        }
        return PAYLOAD.init;
    }

    /// Split the node in two, turning it into a parent of
    /// two new nodes
    Node[2] split(float ratio = 0.5)
    {
        assert(child.length == 0);
        foreach(r ; area.split(ratio, horizontal))
            child ~= new Node(r, !horizontal, this);
        layout();
        return [child[0], child[1]];
    }

    /// Find the node that overlaps the given point
    Node find(const int[] xy) {
        foreach(c ; child) {
            auto rc = c.find(xy);
            if(rc) return rc;
        }
        if(area.isInside(xy))
            return this;
        return null;
    }

    /// Find the node containing the given payload
    Node find(const PAYLOAD p) {
        foreach(c ; child) {
            auto rc = c.find(p);
            if(rc) return rc;
        }
        if(p == payload)
            return this;
        return null;
    }

    /// Find the root of the node tree
    Node root() {
        Node rc = this;
        while(rc.parent)
            rc = rc.parent;
        return rc;
    }

    /// Find the node left of this one
    Node findLeft() {
        return root.find([x-4, y+h/2]);
    }

    /// Find the node right of this one
    Node findRight() {
        return root.find([x+w+3, y+h/2]);
    }

    /// Find the node above this one
    Node findAbove() {
        return root.find([x+w/2, y-4]);
    }

    /// Find the node below this one
    Node findBelow() {
        return root.find([x+w/2, y+h+3]);
    }

    private void list(ref Node[] l) {
        if(child.length == 0)
            l ~= this;
        else
            foreach(c ; child)
                c.list(l);
    }

    /// Flatten the tree into a list
    Node[] list() {
        Node[] l;
        list(l);
        return l;
    }

    /// Add a child to this node
    Node add()
    {
        child ~= new Node(area, !horizontal, this);
        if(child.length > 1)
            child[$-1].weight = 1.0 / (child.length-1);
        layout();
        return child[$-1];
    }

    /// Print the tree
    void print(int level = 0) const
    {
        static const char[80] spaces = ' ';
        foreach(ref c ; child)
            c.print(level+1);
    }

    /// Call a function for each leaf of the tree
    void forEach(void delegate(Node) cb) {
        if(child.length == 0) {
            cb(this);
        }
        else
        foreach(c ; child) {
            c.forEach(cb);
        }
    }

    /// Return the list of nodes from this node to the root
    Node[] parentChain()
    {
        Node[] rc;
        Node n = this;
        while(n) {
            rc ~= n;
            n = n.parent;
        }
        return rc;
    }

    /// Layout the tree from this node, applying weights to
    /// set rectangle sizes
    private void layout() {
        if(child.length == 0)
            return;
        float total = 0.0;
        foreach(c ; child)
            total += c.weight;
        if(horizontal) {

            float x = area.x;
            foreach(c ; child) {
                c.weight = c.weight / total;
                auto w = (c.weight * area.w);
                c.area.x = cast(int)x;
                c.area.h = area.h;
                c.area.y = area.y;
                c.area.w = cast(int)w;
                //c.weight = cast(float)c.area.w / area.w;
                x += w;
                c.layout();
            }
        } else {
            float y = area.y;
            foreach(c ; child) {
                c.weight = c.weight / total;
                auto h = (c.weight * area.h);
                c.area.y = cast(int)y;
                c.area.w = area.w;
                c.area.x = area.x;
                c.area.h = cast(int)h;
                //c.weight = cast(float)c.area.h / area.h;
                y += h;
                c.layout();
            }
        }
    }

    Split!PAYLOAD findSplit(int[2] pos, int size = 4) {
        auto n0 = find([pos[0] - size, pos[1] - size]);
        auto n1 = find([pos[0] + size, pos[1] + size]);
        // TODO: Support 2 split resizing?
        if(n0 != n1 && n0 && n1) {
            return getSplit(n0, n1);
        }
        return Split!PAYLOAD(null, -1);
    }

}



// Represents a horizontal or vertical line between two nodes. The split can be
// moved, causing the nodes to be resized.
struct Split(PAYLOAD)
{
    invariant {
        if(parent) {
            assert(i > 0);
            assert(i < parent.child.length);
            assert(parent.child.length >= 2);
        }
    }
    Node!PAYLOAD parent = null;
    int i;

    bool opCast(T)() if(is(T == bool)) {
        return parent !is null;
    }

    @property int x() const { return parent.child[i].x; }
    @property int y() const { return parent.child[i].y; }

    /// 'Move' this split to a new position, which will
    /// resize the nodes on either side of the split
    void move(int x, int y, int minSize = 1) {

        // child[i] & child[i-1] get new weights
        // all other unaffected

        if(parent.horizontal) {
            auto minx = parent.child[i-1].area.x + minSize;
            if(x < minx) x= minx;
            auto maxx = parent.child[i].area.x + parent.child[i].area.w - minSize;
            if(x > maxx) x = maxx;
            auto dx = x - parent.child[i].area.x;
            auto ns0 = parent.child[i-1].area.w + dx;
            auto ns1 = parent.child[i].area.w - dx;
            if(ns0 <= 0 || ns1 <= 0)
                return;
            parent.child[i-1].weight *= (cast(float)ns0 / parent.child[i-1].area.w);
            parent.child[i].weight *= (cast(float)ns1 / parent.child[i].area.w);
        } else {
            auto miny = parent.child[i-1].area.y + minSize;
            if(y < miny) y= miny;
            auto mayy = parent.child[i].area.y + parent.child[i].area.h - minSize;
            if(y > mayy) y = mayy;
            //writeln(i, " ", parent.child.length);
            auto dy = y - parent.child[i].area.y;
            auto ns0 = parent.child[i-1].area.h + dy;
            auto ns1 = parent.child[i].area.h - dy;
            if(ns0 <= 0 || ns1 <= 0)
                return;
            parent.child[i-1].weight *= (cast(float)ns0 / parent.child[i-1].area.h);
            parent.child[i].weight *= (cast(float)ns1 / parent.child[i].area.h);
        }

        parent.layout();
    }
}


/// Return the pair of nodes that have a common parent, and have
/// 'a' and 'b' as their descendants, respectively
Node!PAYLOAD[2] commonPair(PAYLOAD)(Node!PAYLOAD a, Node!PAYLOAD b) {
    auto ac = a.parentChain();
    auto bc = b.parentChain();
    ac.reverse();
    bc.reverse();
    auto cp = commonPrefix(ac, bc);
    return [ac[cp.length], bc[cp.length]];
}

/// Create a Split object that can be used to resize
/// panes by moving the split
Split!PAYLOAD getSplit(PAYLOAD)(Node!PAYLOAD n0, Node!PAYLOAD n1) {
    auto pair = commonPair(n0, n1);
    auto parent = pair[0].parent;
    int i0 = 999;
    int i1 = 999;
    foreach(int i, c ; parent.child) {
        if(c == pair[0])
            i0 = i;
        else if(c == pair[1])
            i1 = i;
    }

    auto index = max(i0, i1);
    assert(index < 999);

    return Split!(PAYLOAD)(parent, index);

}

unittest {

    auto root = new Node!int(60,40);
    root.add();
    root.add();
    assert(root.child[1].w == 30);
    root.child[1].split();
    assert(root.child[1].child[0].h == 20);
    root.child[1].child[1].split();
    root.child[1].child[1].add();

    //  000111
    //  000111
    //  000234
    //  000234

    auto nodes = root.list();

    auto p = commonPair(nodes[2], nodes[4]);
    auto r = p[0].parent;
    assert(p[0].parent.y == nodes[2].y);
    p = commonPair(nodes[3], nodes[0]);
    assert(p[0].parent == root);

    nodes[2].payload = 99;
    nodes[0].payload = 88;
    assert(root.find(99) == nodes[2]);
    assert(root.find(88) == nodes[0]);

    assert(nodes[3].findAbove() == nodes[1]);
    assert(nodes[3].findRight() == nodes[4]);
    assert(nodes[3].findLeft() == nodes[2]);
    assert(nodes[2].findLeft() == nodes[0]);
    assert(!nodes[3].findBelow());

    root.area.w = 180;
    root.layout();
    root.print();
    assert(nodes[2].w == 30);

    nodes[3].remove();
    root.layout();
    assert(nodes[2].parent.child.length == 2);
    assert(nodes[2].w == 45);
    assert(nodes[4].w == 45);

    auto s = getSplit(nodes[2], nodes[0]);
    assert(s.parent == root);
    assert(s.i == 1);

    s.move(40, 0);
    root.print();
    assert(nodes[0].w == 40);
    assert(nodes[1].x == 40);

    assert(!root.findSplit([10,10]));
    assert(root.findSplit([42,10]));

    s = getSplit(nodes[4], nodes[1]);
    writeln(s.parent);
    s.move(0, 10);
    root.print();
    assert(nodes[2].y == 10);

}

