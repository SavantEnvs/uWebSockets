#include "../src/TopicTree.h"

#include <cassert>
#include <iostream>
#include <string>
#include <vector>

int main() {
    std::vector<std::pair<uWS::Subscriber *, std::string>> got;
    uWS::TopicTree tree([&got](uWS::Subscriber *s, std::pair<std::string_view, std::string_view> m) {
        got.push_back({s, std::string(m.first)});
        return 0;
    });

    uWS::Subscriber exact(nullptr), plus(nullptr), hash(nullptr), other(nullptr);
    tree.subscribe("a/b", &exact);
    tree.subscribe("a/+", &plus);
    tree.subscribe("a/#", &hash);
    tree.subscribe("c/d", &other);

    tree.publish("a/b", {"hello", "hello"});
    tree.drain();
    assert(got.size() == 3);
    for (auto &g : got) {
        assert(g.second == "hello");
        assert(g.first != &other);
    }

    got.clear();
    assert(tree.unsubscribe("a/b", &exact));
    assert(!tree.unsubscribe("a/b", &exact));
    tree.publish("a/b", {"again", "again"});
    tree.drain();
    assert(got.size() == 2);
    for (auto &g : got) {
        assert(g.second == "again");
        assert(g.first == &plus || g.first == &hash);
    }

    got.clear();
    tree.unsubscribeAll(&plus);
    tree.unsubscribeAll(&hash);
    tree.publish("a/b", {"nobody", "nobody"});
    tree.drain();
    assert(got.empty());

    tree.publish("c/d", {"cd", "cd"});
    tree.drain();
    assert(got.size() == 1 && got[0].first == &other && got[0].second == "cd");

    tree.unsubscribeAll(&other);
    std::cout << "TOPICTREE OK" << std::endl;
    return 0;
}
