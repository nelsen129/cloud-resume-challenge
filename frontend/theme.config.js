const YEAR = new Date().getFullYear();

export default {
  footer: (
    <footer>
      <small>
        <time>2023</time> © Patrick Nelsen.
        <a href="/feed.xml">RSS</a>
      </small>
      <style jsx>{`
        footer {
          margin-top: 8rem;
        }
        a {
          float: right;
        }
      `}</style>
    </footer>
  ),
};
